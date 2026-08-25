# services/notification_service/email_templates.py
"""
Minimal, clean HTML email templates for each event type.
Inline CSS for maximum email client compatibility.
"""


def _base_template(title: str, heading: str, body_html: str, color: str = "#4F46E5") -> str:
    return f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;font-family:'Segoe UI',Arial,sans-serif;background:#f4f4f7;">
  <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;margin:32px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.06);">
    <tr>
      <td style="background:{color};padding:24px 32px;">
        <h1 style="margin:0;color:#fff;font-size:22px;font-weight:600;">{title}</h1>
      </td>
    </tr>
    <tr>
      <td style="padding:32px;">
        <h2 style="margin:0 0 16px;color:#1a1a2e;font-size:18px;">{heading}</h2>
        {body_html}
        <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
        <p style="margin:0;color:#888;font-size:12px;">
          Jugaad — Hyperlocal Skill Marketplace, Mysuru<br>
          This is an automated notification. Please do not reply.
        </p>
      </td>
    </tr>
  </table>
</body>
</html>"""


def job_created(data: dict) -> tuple[str, str]:
    subject = f"New Job Request — {data.get('skill', 'Service')}"
    body = _base_template(
        "🔔 Jugaad", "Your job request has been placed!",
        f"""<p style="color:#333;font-size:15px;line-height:1.6;">
          Hi <strong>{data.get('customerName', 'Customer')}</strong>,<br><br>
          We've received your request for <strong>{data.get('skill', 'a service')}</strong>.
          We're finding the best available worker near you right now.
        </p>
        <div style="background:#f0f4ff;padding:16px;border-radius:8px;margin:16px 0;">
          <p style="margin:0;font-size:14px;color:#555;">
            <strong>Job ID:</strong> {data.get('jobId', 'N/A')}<br>
            <strong>Status:</strong> Searching for worker...
          </p>
        </div>""",
    )
    return subject, body


def job_accepted(data: dict) -> tuple[str, str]:
    subject = "Worker Found — Jugaad"
    body = _base_template(
        "✅ Jugaad", "A worker has accepted your job!",
        f"""<p style="color:#333;font-size:15px;line-height:1.6;">
          Hi <strong>{data.get('customerName', 'Customer')}</strong>,<br><br>
          Great news! <strong>{data.get('workerName', 'A worker')}</strong> has accepted your job.
          They'll be at your location shortly.
        </p>
        <div style="background:#ecfdf5;padding:16px;border-radius:8px;margin:16px 0;">
          <p style="margin:0;font-size:14px;color:#555;">
            <strong>Worker:</strong> {data.get('workerName', 'N/A')}<br>
            <strong>Job ID:</strong> {data.get('jobId', 'N/A')}<br>
            <strong>Status:</strong> On the way
          </p>
        </div>""",
        color="#059669",
    )
    return subject, body


def job_ack(data: dict) -> tuple[str, str]:
    subject = "Worker Arrived — Jugaad"
    body = _base_template(
        "📍 Jugaad", "Your worker has arrived!",
        f"""<p style="color:#333;font-size:15px;line-height:1.6;">
          Hi <strong>{data.get('customerName', 'Customer')}</strong>,<br><br>
          <strong>{data.get('workerName', 'Your worker')}</strong> has arrived at your location
          and is ready to start working.
        </p>
        <div style="background:#fefce8;padding:16px;border-radius:8px;margin:16px 0;">
          <p style="margin:0;font-size:14px;color:#555;">
            <strong>Job ID:</strong> {data.get('jobId', 'N/A')}<br>
            <strong>Status:</strong> Worker on-site
          </p>
        </div>""",
        color="#d97706",
    )
    return subject, body


def job_completed(data: dict) -> tuple[str, str]:
    subject = "Job Completed — Jugaad"
    amount = data.get('amount', 0)
    body = _base_template(
        "🎉 Jugaad", "Your job is done!",
        f"""<p style="color:#333;font-size:15px;line-height:1.6;">
          Hi <strong>{data.get('customerName', 'Customer')}</strong>,<br><br>
          The job has been completed successfully by <strong>{data.get('workerName', 'your worker')}</strong>.
          {'Please proceed to payment of <strong>₹' + str(amount) + '</strong>.' if amount else ''}
        </p>
        <div style="background:#eff6ff;padding:16px;border-radius:8px;margin:16px 0;">
          <p style="margin:0;font-size:14px;color:#555;">
            <strong>Job ID:</strong> {data.get('jobId', 'N/A')}<br>
            <strong>Amount:</strong> ₹{amount}<br>
            <strong>Status:</strong> Completed
          </p>
        </div>""",
        color="#2563eb",
    )
    return subject, body


def payment_success(data: dict) -> tuple[str, str]:
    subject = "Payment Confirmed — Jugaad"
    amount = data.get('amount', 0)
    body = _base_template(
        "💰 Jugaad", "Payment received!",
        f"""<p style="color:#333;font-size:15px;line-height:1.6;">
          Hi <strong>{data.get('customerName', 'Customer')}</strong>,<br><br>
          Your payment of <strong>₹{amount}</strong> has been confirmed.
          Thank you for using Jugaad!
        </p>
        <div style="background:#ecfdf5;padding:16px;border-radius:8px;margin:16px 0;">
          <p style="margin:0;font-size:14px;color:#555;">
            <strong>Job ID:</strong> {data.get('jobId', 'N/A')}<br>
            <strong>Amount Paid:</strong> ₹{amount}<br>
            <strong>Worker:</strong> {data.get('workerName', 'N/A')}
          </p>
        </div>""",
        color="#059669",
    )
    return subject, body


# Worker-side templates

def worker_job_accepted(data: dict) -> tuple[str, str]:
    subject = "Job Accepted — Jugaad"
    body = _base_template(
        "🔧 Jugaad Worker", "You accepted a job!",
        f"""<p style="color:#333;font-size:15px;line-height:1.6;">
          Hi <strong>{data.get('workerName', 'Worker')}</strong>,<br><br>
          You've accepted a job from <strong>{data.get('customerName', 'a customer')}</strong>.
          Please head to their location now.
        </p>
        <div style="background:#f0f4ff;padding:16px;border-radius:8px;margin:16px 0;">
          <p style="margin:0;font-size:14px;color:#555;">
            <strong>Job ID:</strong> {data.get('jobId', 'N/A')}<br>
            <strong>Estimated Pay:</strong> ₹{data.get('amount', 'TBD')}
          </p>
        </div>""",
        color="#7c3aed",
    )
    return subject, body


def worker_payment_received(data: dict) -> tuple[str, str]:
    subject = "Payment Received — Jugaad"
    body = _base_template(
        "💰 Jugaad Worker", "You got paid!",
        f"""<p style="color:#333;font-size:15px;line-height:1.6;">
          Hi <strong>{data.get('workerName', 'Worker')}</strong>,<br><br>
          ₹{data.get('amount', 0)} has been added to your Jugaad wallet
          for job <strong>{data.get('jobId', 'N/A')}</strong>.
        </p>""",
        color="#059669",
    )
    return subject, body


# Template mapping
TEMPLATES = {
    "job_created":     {"customer": job_created},
    "job_accepted":    {"customer": job_accepted, "worker": worker_job_accepted},
    "job_ack":         {"customer": job_ack},
    "job_completed":   {"customer": job_completed},
    "payment_success": {"customer": payment_success, "worker": worker_payment_received},
}
