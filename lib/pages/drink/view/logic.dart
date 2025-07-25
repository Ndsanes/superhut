import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/login/view.dart';

import '../api/drink_api.dart';
import 'state.dart';

class FunctionDrinkLogic extends GetxController {
  final FunctionDrinkState state = FunctionDrinkState();
  final drinkApi = DrinkApi();

  @override
  onInit() {
    super.onInit();
    checkLogin();
    // 获取token
    drinkApi.getToken().then((value) {
      state.tokenController.text = value;
    });
  }

  @override
  void dispose() {
    state.deviceStatusTimer?.cancel();
    state.tokenController.dispose();
    state.deviceStatusTimer?.cancel();
    Get.delete<FunctionDrinkLogic>();
    super.dispose();
  }

  /// 判断是否需要跳转登录
  void checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLogin = prefs.getBool("hui798IsLogin") ?? false;
    if (!isLogin) {
      Get.off(DrinkLoginPage());
      //Get.to(DrinkLoginPage());
    } else {
      getDeviceList();
    }
  }

  /// 获取喝水设备列表
  Future<void> getDeviceList() async {
    await drinkApi.deviceList().then((value) {
      if (value[0]["name"] == "Account failure") {
        state.deviceList.clear();
        setChoiceDevice(-1);
        state.drinkStatus.value = false;
        update();
        checkLogin();
      } else {
        state.deviceList.value = value;
        setChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1);
        update();
      }
    });
  }

  /// 收藏或取消收藏设备
  Future<bool> favoDevice(
    String id,
    bool isUnFavo,
    BuildContext context,
  ) async {
    print(
      "QHJqqYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY",
    );
    return await drinkApi.favoDevice(id: id, isUnFavo: isUnFavo).then((value) {
      return value;
    });
  }

  /// 格式化设备名称
  String formatDeviceName(String name) {
    if (name.contains("栋")) {
      return name.replaceAll("栋", "-");
    } else {
      return name;
    }
  }

  /// 改变选中的设备值
  void setChoiceDevice(int device) {
    state.choiceDevice.value = device;
    update();
  }

  /// 开始喝水
  void startDrink(context) {
    drinkApi
        .startDrink(id: state.deviceList[state.choiceDevice.value]["id"])
        .then((value) {
          if (value) {
            int count = 0;
            state.drinkStatus.value = true;
            getDeviceList();
            state.deviceStatusTimer = Timer.periodic(
              const Duration(seconds: 1),
              (timer) async {
                bool isAvailable = await drinkApi.isAvailableDevice(
                  id: state.deviceList[state.choiceDevice.value]["id"],
                );
                if (isAvailable && count > 3) {
                  state.drinkStatus.value = false;
                  state.deviceStatusTimer?.cancel();
                  update();
                } else if (isAvailable) {
                  count++;
                }
              },
            );
          } else {
            Get.snackbar(
              '失败',
              '开启失败',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: Duration(seconds: 3),
              margin: EdgeInsets.all(10),
              borderRadius: 10,
              icon: Icon(Icons.error, color: Colors.white),
            );
          }
          update();
        });
  }

  /// 结束喝水
  void endDrink(context) {
    drinkApi
        .endDrink(id: state.deviceList[state.choiceDevice.value]["id"])
        .then((value) {
          if (value) {
            state.deviceStatusTimer?.cancel();
            state.drinkStatus.value = false;
          } else {
            Get.snackbar(
              '失败',
              '结算失败',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: Duration(seconds: 3),
              margin: EdgeInsets.all(10),
              borderRadius: 10,
              icon: Icon(Icons.error, color: Colors.white),
            );
          }
          update();
        });
  }

  /// 删除相对应的device
  void removeDeviceByName(String name) {
    state.deviceList.removeWhere((element) => element["name"] == name);
    update();
  }

  /// 扫描二维码逻辑
  void scanQRCode(BuildContext context) async {
    final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
    QRViewController? controller;

    var result = await Get.to(
      () => QRView(
        key: qrKey,
        onQRViewCreated: (QRViewController qrController) {
          controller = qrController;
          controller!.scannedDataStream.listen((scanData) {
            controller?.stopCamera();
            Get.back(result: scanData);
          });
        },
      ),
    );

    if (result != null) {
      String enc = (result as Barcode).code!;
      enc = enc.split("/").last;
      bool isFavo = await favoDevice(enc, false, context);

      if (isFavo) {
        getDeviceList();
      }
    }
  }

  /// 设置token
  void setToken(String token) {
    drinkApi.setToken(token: token).then((value) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("hui798IsLogin", true);
      await getDeviceList();
      update();
    });
  }
}
