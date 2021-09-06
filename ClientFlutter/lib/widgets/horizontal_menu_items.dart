import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:linkso/resources/palette.dart';
import 'package:linkso/resources/theme.dart';

import '../controller_instances.dart';

class HorizontalMenuItem extends StatelessWidget {
  const HorizontalMenuItem({
    Key? key,
    required this.itemName,
    this.onTap,
  }) : super(key: key);

  final String itemName;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double _width = MediaQuery.of(context).size.width;
    return InkWell(
      onTap: onTap,
      onHover: (value) {
        value ? menuController.onHover(itemName) : menuController.onHover("Not hover");
      },
      child: Obx(
        () => Container(
          color: menuController.isHover(itemName) ? AppColors.lightPrimary.withOpacity(0.3) : Colors.transparent,
          child: Row(
            children: [
              Visibility(
                visible: menuController.isHover(itemName) || menuController.isActive(itemName),
                maintainSize: true,
                maintainState: true,
                maintainAnimation: true,
                child: Container(
                  width: 6,
                  height: 40,
                  color: AppColors.darkPrimary,
                ),
              ),
              SizedBox(width: _width / 80),
              Padding(
                padding: const EdgeInsets.all(16),
                child: menuController.returnIconFor(itemName),
              ),
              if (!menuController.isActive(itemName))
                Flexible(
                  child: Text(
                    itemName,
                    style: Theme.of(context).textTheme.m16.copyWith(
                          color: menuController.isHover(itemName) ? AppColors.lightPrimaryVariant : AppColors.lightPrimary,
                        ),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    itemName,
                    style: Theme.of(context).textTheme.m16.copyWith(
                          color: AppColors.darkPrimary,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
