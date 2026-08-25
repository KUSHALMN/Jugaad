import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkerRegistrationData {
  final String fullName;
  final String phoneNumber;
  final String workCategory;
  
  final Uint8List? profilePhotoBytes;
  final String? profilePhotoName;
  
  final Uint8List? aadhaarPhotoBytes;
  final String? aadhaarPhotoName;
  
  final String? profilePhotoUrl;
  final String? aadhaarPhotoUrl;

  const WorkerRegistrationData({
    this.fullName = '',
    this.phoneNumber = '',
    this.workCategory = '',
    this.profilePhotoBytes,
    this.profilePhotoName,
    this.aadhaarPhotoBytes,
    this.aadhaarPhotoName,
    this.profilePhotoUrl,
    this.aadhaarPhotoUrl,
  });

  WorkerRegistrationData copyWith({
    String? fullName,
    String? phoneNumber,
    String? workCategory,
    Uint8List? profilePhotoBytes,
    String? profilePhotoName,
    Uint8List? aadhaarPhotoBytes,
    String? aadhaarPhotoName,
    String? profilePhotoUrl,
    String? aadhaarPhotoUrl,
    bool clearProfile = false,
    bool clearAadhaar = false,
  }) {
    return WorkerRegistrationData(
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      workCategory: workCategory ?? this.workCategory,
      profilePhotoBytes: clearProfile ? null : (profilePhotoBytes ?? this.profilePhotoBytes),
      profilePhotoName: clearProfile ? null : (profilePhotoName ?? this.profilePhotoName),
      aadhaarPhotoBytes: clearAadhaar ? null : (aadhaarPhotoBytes ?? this.aadhaarPhotoBytes),
      aadhaarPhotoName: clearAadhaar ? null : (aadhaarPhotoName ?? this.aadhaarPhotoName),
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      aadhaarPhotoUrl: aadhaarPhotoUrl ?? this.aadhaarPhotoUrl,
    );
  }
}

class WorkerRegistrationNotifier extends Notifier<WorkerRegistrationData> {
  @override
  WorkerRegistrationData build() => const WorkerRegistrationData();

  void setStep1(String name, String phone, String category) {
    state = state.copyWith(fullName: name, phoneNumber: phone, workCategory: category);
    print('[REGISTRATION] Step 1: name=$name, phone=$phone, category=$category');
  }

  void setProfilePhoto(Uint8List bytes, String name) {
    state = state.copyWith(profilePhotoBytes: bytes, profilePhotoName: name);
    print('[REGISTRATION] Profile photo set: $name (${bytes.length} bytes)');
  }

  void setAadhaarPhoto(Uint8List bytes, String name) {
    state = state.copyWith(aadhaarPhotoBytes: bytes, aadhaarPhotoName: name);
    print('[REGISTRATION] Aadhaar photo set: $name (${bytes.length} bytes)');
  }

  void setUploadedUrls(String profileUrl, String aadhaarUrl) {
    state = state.copyWith(profilePhotoUrl: profileUrl, aadhaarPhotoUrl: aadhaarUrl);
    print('[REGISTRATION] URLs set: profile=$profileUrl, aadhaar=$aadhaarUrl');
  }

  void reset() {
    state = const WorkerRegistrationData();
  }
}

final workerRegistrationProvider = NotifierProvider<WorkerRegistrationNotifier, WorkerRegistrationData>(
  WorkerRegistrationNotifier.new,
);
