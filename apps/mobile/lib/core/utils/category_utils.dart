/// Centralized service category normalizer for Jugaad.
/// Maps vernacular strings (Kannada, Hindi, English), bilingual chips,
/// and natural language queries to canonical category labels:
/// 'Plumber', 'Electrician', 'AC Service', 'Cleaning', 'Laptop Repair',
/// 'Phone Repair', 'Carpenter', 'Painter', 'RO Service'.
class CategoryUtils {
  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';

    String text = raw.trim();
    if (text.contains('/')) {
      final parts = text.split('/');
      final first = parts[0].trim();
      if (first.isNotEmpty) {
        text = first;
      }
    }

    final lower = text.toLowerCase().replaceAll('_', ' ');

    if (lower == 'all' || lower == 'any' || lower == '*' || lower == 'services') {
      return '';
    }

    // Plumber
    if (lower.contains('plumb') ||
        lower.contains('pipe') ||
        lower.contains('leak') ||
        lower.contains('tap') ||
        lower.contains('drain') ||
        lower.contains('flush') ||
        lower.contains('valve') ||
        lower.contains('neeru') ||
        lower.contains('paani') ||
        lower.contains('ನೀರು') ||
        lower.contains('ಪ್ಲಂಬರ್') ||
        lower.contains('प्लंबर') ||
        lower.contains('पानी')) {
      return 'Plumber';
    }

    // Electrician
    if (lower.contains('electr') ||
        lower.contains('light') ||
        lower.contains('switch') ||
        lower.contains('fan') ||
        lower.contains('wire') ||
        lower.contains('wiring') ||
        lower.contains('mcb') ||
        lower.contains('current') ||
        lower.contains('karnt') ||
        lower.contains('pankha') ||
        lower.contains('bijli') ||
        lower.contains('ಇಲೆಕ್ಟ್ರಿ') ||
        lower.contains('इलेक्ट्री') ||
        lower.contains('पंखा') ||
        lower.contains('बिजली')) {
      return 'Electrician';
    }

    // Laptop / Computer Repair (check before generic electronics/ac)
    if (lower.contains('laptop') ||
        lower.contains('computer') ||
        lower.contains('pc') ||
        lower.contains('macbook') ||
        lower.contains('ಲ್ಯಾಪ್ಟಾಪ್') ||
        lower.contains('लैपटॉप')) {
      return 'Laptop Repair';
    }

    // Phone Repair
    if (lower.contains('phone') ||
        lower.contains('mobile') ||
        lower.contains('iphone') ||
        lower.contains('smartphone') ||
        lower.contains('screen replac') ||
        lower.contains('ಮೋಬೈಲ್') ||
        lower.contains('फोन') ||
        lower.contains('मोबाइल')) {
      return 'Phone Repair';
    }

    // AC Service / Repair (use word boundary for 'ac' to avoid matching 'machine', 'macbook', etc.)
    final acRegex = RegExp(r'(^|[^a-zA-Z])ac([^a-zA-Z]|$)');
    if (acRegex.hasMatch(lower) ||
        lower.contains('a/c') ||
        lower.contains('cooling') ||
        lower.contains('air cond') ||
        lower.contains('chilling') ||
        lower.contains('compressor') ||
        lower.contains('ಎಸಿ') ||
        lower.contains('एसी')) {
      return 'AC Service';
    }

    // Home Cleaning
    if (lower.contains('clean') ||
        lower.contains('safai') ||
        lower.contains('swach') ||
        lower.contains('sofa') ||
        lower.contains('deep clean') ||
        lower.contains('maid') ||
        lower.contains('ಸ್ವಚ್ಛ') ||
        lower.contains('सफाई')) {
      return 'Cleaning';
    }

    // Carpenter
    if (lower.contains('carpent') ||
        lower.contains('wood') ||
        lower.contains('furniture') ||
        lower.contains('door') ||
        lower.contains('lock') ||
        lower.contains('table') ||
        lower.contains('bed') ||
        lower.contains('ಕಾರ್ಪೆಂಟರ್') ||
        lower.contains('बढ़ई')) {
      return 'Carpenter';
    }

    // Painter
    if (lower.contains('paint') ||
        lower.contains('wall') ||
        lower.contains('putty') ||
        lower.contains('whitewash') ||
        lower.contains('color') ||
        lower.contains('ಪೇಂಟರ್') ||
        lower.contains('पेंटर')) {
      return 'Painter';
    }

    // RO Water Purifier
    if (lower.contains('purifier') ||
        lower.contains('water pur') ||
        lower.contains('ro') ||
        lower.contains('aquaguard') ||
        lower.contains('kent') ||
        lower.contains('candle') ||
        lower.contains('ಆರ್ಒ') ||
        lower.contains('आरओ')) {
      return 'RO Service';
    }

    // Stove / Gas Repair
    if (lower.contains('stove') ||
        lower.contains('gas') ||
        lower.contains('chulha') ||
        lower.contains('burner') ||
        lower.contains('hob') ||
        lower.contains('cylinder') ||
        lower.contains('ಚೂಲ್ಹಾ') ||
        lower.contains('चूल्हा')) {
      return 'Plumber';
    }

    return text;
  }
}
