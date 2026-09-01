use std::{env, error::Error, io, time::Duration};

use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpStream,
    task::JoinSet,
    time::Instant,
};
use url::Url;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let arguments = env::args().skip(1).collect::<Vec<_>>();
    if !(1..=4).contains(&arguments.len()) {
        return Err(
            "usage: redirect_load URL [requests=250] [concurrency=25] [max_p95_ms=250]".into(),
        );
    }
    let url = Url::parse(&arguments[0])?;
    if url.scheme() != "http" || url.host_str().is_none() {
        return Err("the local load target must be an absolute http URL".into());
    }
    let request_count = parse_positive(arguments.get(1), 250, "requests")?;
    let concurrency = parse_positive(arguments.get(2), 25, "concurrency")?;
    let maximum_p95_ms = parse_positive(arguments.get(3), 250, "max_p95_ms")?;
    if concurrency > request_count {
        return Err("concurrency must not exceed requests".into());
    }

    let started = Instant::now();
    let mut tasks = JoinSet::new();
    let mut launched = 0usize;
    for client_index in 0..concurrency {
        tasks.spawn(request_once(url.clone(), client_index));
        launched += 1;
    }
    let mut latencies = Vec::with_capacity(request_count);
    let mut redirects = 0usize;
    while let Some(result) = tasks.join_next().await {
        let sample = result??;
        if sample.status == 307 {
            redirects += 1;
        }
        latencies.push(sample.elapsed);
        if launched < request_count {
            tasks.spawn(request_once(url.clone(), launched));
            launched += 1;
        }
    }
    latencies.sort_unstable();
    let p50 = percentile(&latencies, 50);
    let p95 = percentile(&latencies, 95);
    let p99 = percentile(&latencies, 99);
    let total = started.elapsed();
    println!("requests={request_count} concurrency={concurrency} redirects={redirects}");
    println!(
        "total_ms={} requests_per_second={:.2} p50_ms={} p95_ms={} p99_ms={}",
        total.as_millis(),
        request_count as f64 / total.as_secs_f64(),
        p50.as_millis(),
        p95.as_millis(),
        p99.as_millis()
    );
    if redirects != request_count {
        return Err(
            format!("expected {request_count} HTTP 307 responses, received {redirects}").into(),
        );
    }
    if p95 > Duration::from_millis(maximum_p95_ms as u64) {
        return Err(format!(
            "p95 latency {} ms exceeds limit {maximum_p95_ms} ms",
            p95.as_millis()
        )
        .into());
    }
    Ok(())
}

struct Sample {
    status: u16,
    elapsed: Duration,
}

async fn request_once(url: Url, client_index: usize) -> Result<Sample, io::Error> {
    let host = url
        .host_str()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "URL host is missing"))?;
    let port = url.port_or_known_default().unwrap_or(80);
    let mut path = url.path().to_owned();
    if path.is_empty() {
        path.push('/');
    }
    if let Some(query) = url.query() {
        path.push('?');
        path.push_str(query);
    }
    let authority = if port == 80 {
        host.to_owned()
    } else {
        format!("{host}:{port}")
    };
    let third_octet = (client_index / 254) % 254;
    let fourth_octet = (client_index % 254) + 1;
    let request = format!(
        "GET {path} HTTP/1.1\r\nHost: {authority}\r\nUser-Agent: linkso-local-load-test/1\r\nX-Forwarded-For: 198.18.{third_octet}.{fourth_octet}\r\nConnection: close\r\n\r\n"
    );
    let started = Instant::now();
    let connect_host = if host.eq_ignore_ascii_case("localhost") {
        "127.0.0.1"
    } else {
        host
    };
    let mut stream = TcpStream::connect((connect_host, port)).await?;
    stream.write_all(request.as_bytes()).await?;
    let mut response = Vec::with_capacity(1024);
    let mut chunk = [0_u8; 1024];
    while !response.windows(4).any(|window| window == b"\r\n\r\n") {
        let read = stream.read(&mut chunk).await?;
        if read == 0 {
            break;
        }
        response.extend_from_slice(&chunk[..read]);
        if response.len() > 16 * 1024 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "HTTP response headers exceed 16 KiB",
            ));
        }
    }
    let status = parse_status(&response)?;
    Ok(Sample {
        status,
        elapsed: started.elapsed(),
    })
}

fn parse_status(response: &[u8]) -> Result<u16, io::Error> {
    let first_line = response
        .split(|byte| *byte == b'\n')
        .next()
        .and_then(|line| std::str::from_utf8(line).ok())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "HTTP status line is missing"))?;
    first_line
        .split_whitespace()
        .nth(1)
        .and_then(|status| status.parse().ok())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "HTTP status is invalid"))
}

fn parse_positive(
    value: Option<&String>,
    default: usize,
    name: &str,
) -> Result<usize, Box<dyn Error>> {
    let value = value.map_or(Ok(default), |value| value.parse::<usize>())?;
    if value == 0 {
        return Err(format!("{name} must be greater than zero").into());
    }
    Ok(value)
}

fn percentile(values: &[Duration], percentile: usize) -> Duration {
    let index = (values.len() * percentile).div_ceil(100).saturating_sub(1);
    values[index]
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::{parse_status, percentile};

    #[test]
    fn parses_status_and_uses_nearest_rank_percentiles() {
        assert_eq!(
            parse_status(b"HTTP/1.1 307 Temporary Redirect\r\n").unwrap(),
            307
        );
        let values = (1..=100).map(Duration::from_millis).collect::<Vec<_>>();
        assert_eq!(percentile(&values, 95), Duration::from_millis(95));
    }
}
