import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/platform_config_service.dart';

// --- DATA MODEL ---
class PostJobData {
  static const Object _unset = Object();

  final String skill;
  final String urgency; // 'now' | 'scheduled'
  final DateTime? scheduledAt;
  final String description;
  final double lat;
  final double lng;
  final String address;
  final String jobType; // 'normal' | 'emergency'
  final String serviceFeeType; // 'normal' | 'emergency'
  final double surchargeAmount;

  const PostJobData({
    this.skill = '',
    this.urgency = 'now',
    this.scheduledAt,
    this.description = '',
    this.lat = 0.0,
    this.lng = 0.0,
    this.address = '',
    this.jobType = 'normal',
    this.serviceFeeType = 'normal',
    this.surchargeAmount = 0.0,
  });

  PostJobData copyWith({
    String? skill,
    String? urgency,
    Object? scheduledAt = _unset,
    String? description,
    double? lat,
    double? lng,
    String? address,
    String? jobType,
    String? serviceFeeType,
    double? surchargeAmount,
  }) {
    return PostJobData(
      skill: skill ?? this.skill,
      urgency: urgency ?? this.urgency,
      scheduledAt: scheduledAt == _unset ? this.scheduledAt : scheduledAt as DateTime?,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      jobType: jobType ?? this.jobType,
      serviceFeeType: serviceFeeType ?? this.serviceFeeType,
      surchargeAmount: surchargeAmount ?? this.surchargeAmount,
    );
  }

  Map<String, dynamic> toApiPayload() => {
    'skill': skill,
    'urgency': urgency,
    'scheduled_at': scheduledAt?.toIso8601String(),
    'description': description,
    'lat': lat,
    'lng': lng,
    'job_type': jobType,
    'service_fee_type': serviceFeeType,
    'surcharge_amount': surchargeAmount,
  };
}

// --- STATE NOTIFIER (Riverpod v2: Notifier) ---
class PostJobNotifier extends Notifier<PostJobData> {
  @override
  PostJobData build() => const PostJobData();

  void setSkill(String skill) {
    state = state.copyWith(skill: skill);
    print('[POST_JOB] Skill set: $skill');
  }

  void setUrgency(String urgency) {
    state = state.copyWith(urgency: urgency);
  }

  void setScheduledAt(DateTime? dt) {
    state = state.copyWith(scheduledAt: dt);
  }

  void setDescription(String desc) {
    state = state.copyWith(description: desc);
  }

  void setLocation(double lat, double lng, String address) {
    state = state.copyWith(lat: lat, lng: lng, address: address);
    print('[POST_JOB] Step 2: description set, location: $address ($lat, $lng)');
  }

  void setEmergency(bool isEmergency) {
    final surchargeAmount = isEmergency ? PlatformConfigService().surgeFee : 0.0;
    state = state.copyWith(
      jobType: isEmergency ? 'emergency' : 'normal',
      serviceFeeType: isEmergency ? 'emergency' : 'normal',
      surchargeAmount: surchargeAmount,
    );
    print('[POST_JOB] Emergency set: $isEmergency, surcharge: $surchargeAmount');
  }

  void reset() {
    state = const PostJobData();
  }
}

// --- PROVIDER ---
final postJobProvider = NotifierProvider<PostJobNotifier, PostJobData>(
  PostJobNotifier.new,
);
