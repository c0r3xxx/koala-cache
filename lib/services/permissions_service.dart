import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/widgets/snackbar.dart';

/// Service for handling app permissions
class PermissionsService {
  /// Request storage permissions for Android
  ///
  /// For Android 11+ (API 30+), this requests MANAGE_EXTERNAL_STORAGE permission.
  /// Shows an informative snackbar with a link to settings if permission is denied.
  ///
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) {
      return true;
    }

    final status = await Permission.manageExternalStorage.request();

    if (!status.isGranted && context.mounted) {
      AppSnackBar.showInfo(
        context,
        'Storage access permission is required to scan image directories',
        action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
      );
      return false;
    }

    return status.isGranted;
  }

  /// Check if storage permission is currently granted
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    return await Permission.manageExternalStorage.isGranted;
  }
}
