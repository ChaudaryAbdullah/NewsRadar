"""
Email service for NewsRadar - handles all email operations.
Supports SendGrid and SMTP fallback.
"""

import os
import logging
from datetime import datetime
from typing import Optional
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import smtplib

try:
    from sendgrid import SendGridAPIClient
    from sendgrid.helpers.mail import Mail, Email, To, Content
    HAS_SENDGRID = True
except ImportError:
    HAS_SENDGRID = False

from core.config import settings
from db.database import SessionLocal
from db.models import EmailLog
from core.security import new_id

logger = logging.getLogger(__name__)


class EmailService:
    """Unified email service with SendGrid primary and SMTP fallback"""

    def __init__(self):
        self.sendgrid_key = os.getenv("SENDGRID_API_KEY", "").strip()
        self.smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user = os.getenv("SMTP_USER", "").strip()
        self.smtp_password = os.getenv("SMTP_PASSWORD", "").strip()
        self.from_email = os.getenv("SENDGRID_FROM_EMAIL", "noreply@newsradar.com")
        self.from_name = os.getenv("SENDGRID_FROM_NAME", "NewsRadar")

    async def send_verification_email(
        self, email: str, full_name: str, verification_token: str
    ) -> bool:
        """Send email verification link"""
        verify_url = f"{settings.APP_URL}/verify-email?token={verification_token}"
        html_content = f"""
        <h2>Welcome to NewsRadar, {full_name}!</h2>
        <p>Please verify your email address to complete your registration.</p>
        <p><a href="{verify_url}" style="background-color: #1f2937; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px; display: inline-block;">
            Verify Email Address
        </a></p>
        <p>Or copy this link: {verify_url}</p>
        <p>This link expires in 24 hours.</p>
        """
        return await self.send_email(
            to_email=email,
            subject="Verify Your NewsRadar Email",
            html_content=html_content,
            email_type="verification",
        )

    async def send_invitation_email(
        self,
        email: str,
        full_name: str,
        role: str,
        invitation_token: str,
        invited_by: str,
    ) -> bool:
        """Send user invitation email"""
        accept_url = f"{settings.APP_URL}/accept-invitation?token={invitation_token}"
        html_content = f"""
        <h2>You're Invited to NewsRadar!</h2>
        <p>{invited_by} has invited you to join NewsRadar as a <strong>{role}</strong>.</p>
        <p><a href="{accept_url}" style="background-color: #1f2937; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px; display: inline-block;">
            Accept Invitation
        </a></p>
        <p>Or copy this link: {accept_url}</p>
        <p>This invitation expires in 72 hours.</p>
        """
        return await self.send_email(
            to_email=email,
            subject=f"You're Invited to NewsRadar ({role})",
            html_content=html_content,
            email_type="invitation",
        )

    async def send_password_reset_email(
        self, email: str, full_name: str, reset_token: str
    ) -> bool:
        """Send password reset link"""
        reset_url = f"{settings.APP_URL}/reset-password?token={reset_token}"
        html_content = f"""
        <h2>Reset Your NewsRadar Password</h2>
        <p>Hi {full_name},</p>
        <p>We received a request to reset your password. Click the link below to set a new password.</p>
        <p><a href="{reset_url}" style="background-color: #1f2937; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px; display: inline-block;">
            Reset Password
        </a></p>
        <p>Or copy this link: {reset_url}</p>
        <p>This link expires in 60 minutes.</p>
        <p>If you didn't request this, ignore this email.</p>
        """
        return await self.send_email(
            to_email=email,
            subject="Reset Your NewsRadar Password",
            html_content=html_content,
            email_type="reset",
        )

    async def send_alert_notification(
        self, email: str, alert_title: str, article_title: str, article_url: str
    ) -> bool:
        """Send alert notification email"""
        html_content = f"""
        <h2>NewsRadar Alert: {alert_title}</h2>
        <p>An article matching your alert has been detected:</p>
        <p><strong>{article_title}</strong></p>
        <p><a href="{article_url}" style="background-color: #1f2937; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px; display: inline-block;">
            View Article
        </a></p>
        """
        return await self.send_email(
            to_email=email,
            subject=f"Alert: {alert_title}",
            html_content=html_content,
            email_type="alert",
        )

    async def send_email(
        self,
        to_email: str,
        subject: str,
        html_content: str,
        email_type: str = "notification",
    ) -> bool:
        """
        Send email via SendGrid or SMTP.
        
        Args:
            to_email: Recipient email address
            subject: Email subject
            html_content: HTML email body
            email_type: Type of email (for logging)
            
        Returns:
            True if sent successfully, False otherwise
        """
        try:
            if self.sendgrid_key and HAS_SENDGRID:
                success = await self._send_via_sendgrid(to_email, subject, html_content)
            elif self.smtp_user and self.smtp_password:
                success = await self._send_via_smtp(to_email, subject, html_content)
            else:
                logger.warning("No email service configured (SendGrid or SMTP)")
                success = False

            # Log the email attempt
            self._log_email(to_email, subject, email_type, "sent" if success else "failed")
            return success

        except Exception as e:
            logger.error(f"Email error: {str(e)}")
            self._log_email(to_email, subject, email_type, "failed", str(e))
            return False

    async def _send_via_sendgrid(
        self, to_email: str, subject: str, html_content: str
    ) -> bool:
        """Send email via SendGrid"""
        try:
            mail = Mail(
                from_email=Email(self.from_email, self.from_name),
                to_emails=To(to_email),
                subject=subject,
                html_content=Content("text/html", html_content),
            )
            sg = SendGridAPIClient(self.sendgrid_key)
            response = sg.send(mail)
            return response.status_code in [200, 201, 202]
        except Exception as e:
            logger.error(f"SendGrid error: {str(e)}")
            return False

    async def _send_via_smtp(
        self, to_email: str, subject: str, html_content: str
    ) -> bool:
        """Send email via SMTP (Gmail, etc.)"""
        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = self.from_email
            msg["To"] = to_email

            part = MIMEText(html_content, "html")
            msg.attach(part)

            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_user, self.smtp_password)
                server.sendmail(self.from_email, to_email, msg.as_string())
            return True
        except Exception as e:
            logger.error(f"SMTP error: {str(e)}")
            return False

    def _log_email(
        self,
        recipient: str,
        subject: str,
        email_type: str,
        status: str,
        error_message: Optional[str] = None,
    ):
        """Log email attempt to database"""
        try:
            db = SessionLocal()
            log = EmailLog(
                id=new_id("eml"),
                recipient=recipient,
                subject=subject,
                email_type=email_type,
                status=status,
                error_message=error_message,
            )
            db.add(log)
            db.commit()
            db.close()
        except Exception as e:
            logger.error(f"Failed to log email: {str(e)}")


# Global instance
email_service = EmailService()
