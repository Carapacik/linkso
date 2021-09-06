using System;
using System.Collections.Generic;

namespace Domain.Entities;

public class User
{
    public int Id { get; set; }

    public string Login { get; set; }

    public string Email { get; set; }

    public Password Password { get; set; }
    public DateTime RegisterDate { get; set; }

    public ICollection<Link> Links { get; set; }
}