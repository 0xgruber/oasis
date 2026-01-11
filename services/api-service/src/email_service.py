"""
Email Service Module
Handles SMTP email sending with template support
"""

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional, Dict, Any
import structlog

logger = structlog.get_logger()


class EmailService:
    """Service for sending emails via SMTP"""

    def __init__(self, smtp_config: Dict[str, Any]):
        """
        Initialize email service with SMTP configuration

        Args:
            smtp_config: Dictionary containing SMTP settings
                - host: SMTP server hostname
                - port: SMTP server port
                - use_tls: Whether to use TLS
                - use_ssl: Whether to use SSL
                - username: SMTP username
                - password: SMTP password
                - from_email: Sender email address
                - from_name: Sender display name
        """
        self.config = smtp_config
        self.enabled = smtp_config.get("enabled", False)

    def send_email(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
    ) -> bool:
        """
        Send an email

        Args:
            to_email: Recipient email address
            subject: Email subject line
            html_body: HTML content of email
            text_body: Plain text fallback (optional)

        Returns:
            bool: True if email sent successfully, False otherwise
        """
        if not self.enabled:
            logger.warning("email_sending_disabled", recipient=to_email)
            return False

        try:
            # Create message
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = f"{self.config['from_name']} <{self.config['from_email']}>"
            msg["To"] = to_email

            # Add text and HTML parts
            if text_body:
                part1 = MIMEText(text_body, "plain")
                msg.attach(part1)

            part2 = MIMEText(html_body, "html")
            msg.attach(part2)

            # Connect to SMTP server
            if self.config.get("use_ssl", False):
                # SSL connection
                server = smtplib.SMTP_SSL(self.config["host"], self.config["port"])
            else:
                # Standard connection
                server = smtplib.SMTP(self.config["host"], self.config["port"])

                # Upgrade to TLS if configured
                if self.config.get("use_tls", True):
                    server.starttls()

            # Authenticate
            if self.config.get("username") and self.config.get("password"):
                server.login(self.config["username"], self.config["password"])

            # Send email
            server.send_message(msg)
            server.quit()

            logger.info(
                "email_sent_successfully",
                recipient=to_email,
                subject=subject,
            )
            return True

        except smtplib.SMTPAuthenticationError as e:
            logger.error(
                "smtp_authentication_failed",
                error=str(e),
                host=self.config.get("host"),
            )
            return False

        except smtplib.SMTPException as e:
            logger.error(
                "smtp_error",
                error=str(e),
                recipient=to_email,
            )
            return False

        except Exception as e:
            logger.error(
                "email_send_failed",
                error=str(e),
                recipient=to_email,
            )
            return False

    def send_user_invite(
        self,
        to_email: str,
        username: str,
        login_url: str,
    ) -> bool:
        """
        Send user invitation email

        Args:
            to_email: New user's email address
            username: New user's username
            login_url: URL to access the platform

        Returns:
            bool: True if sent successfully
        """
        subject = "Welcome to O.A.S.I.S. - Your Account Has Been Created"

        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #0a0e27 0%, #1a237e 100%); color: #00ff9f; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 8px 8px; }}
        .button {{ display: inline-block; background: #00ff9f; color: #0a0e27; padding: 12px 30px; text-decoration: none; border-radius: 5px; font-weight: bold; margin: 20px 0; }}
        .info-box {{ background: #fff; padding: 15px; border-left: 4px solid #00ff9f; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 30px; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>O.A.S.I.S.</h1>
            <p>Open-Source AI SIEM Intelligence System</p>
        </div>
        <div class="content">
            <h2>Welcome to O.A.S.I.S.!</h2>
            <p>Your account has been created and you're ready to get started.</p>
            
            <div class="info-box">
                <strong>Your Username:</strong> {username}
            </div>
            
            <h3>Getting Started</h3>
            <p>To set up your password and access your account:</p>
            <ol>
                <li>Click the button below to access the login page</li>
                <li>Click "Forgot Password" on the login form</li>
                <li>Enter your username (<strong>{username}</strong>)</li>
                <li>You'll receive a temporary password via email</li>
                <li>Log in with the temporary password</li>
                <li>You'll be prompted to create a new secure password</li>
            </ol>
            
            <a href="{login_url}" class="button">Access O.A.S.I.S.</a>
            
            <p><strong>Need Help?</strong><br>
            If you have any questions or need assistance, please contact your system administrator.</p>
        </div>
        <div class="footer">
            <p>This is an automated message from O.A.S.I.S. Please do not reply to this email.</p>
        </div>
    </div>
</body>
</html>
"""

        text_body = f"""
Welcome to O.A.S.I.S.!

Your account has been created. Here are your login details:

Username: {username}

To set up your password:
1. Visit: {login_url}
2. Click "Forgot Password"
3. Enter your username: {username}
4. Check your email for a temporary password
5. Log in and create a new secure password

Need help? Contact your system administrator.

---
This is an automated message from O.A.S.I.S.
"""

        return self.send_email(to_email, subject, html_body, text_body)

    def send_password_reset(
        self,
        to_email: str,
        username: str,
        temporary_password: str,
        login_url: str,
    ) -> bool:
        """
        Send password reset email with temporary password

        Args:
            to_email: User's email address
            username: User's username
            temporary_password: Temporary password to use
            login_url: URL to access the platform

        Returns:
            bool: True if sent successfully
        """
        subject = "O.A.S.I.S. - Password Reset"

        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #0a0e27 0%, #1a237e 100%); color: #00ff9f; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 8px 8px; }}
        .button {{ display: inline-block; background: #00ff9f; color: #0a0e27; padding: 12px 30px; text-decoration: none; border-radius: 5px; font-weight: bold; margin: 20px 0; }}
        .warning-box {{ background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; }}
        .credentials {{ background: #fff; padding: 20px; border: 2px solid #00ff9f; border-radius: 5px; font-family: monospace; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 30px; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>O.A.S.I.S.</h1>
            <p>Password Reset Request</p>
        </div>
        <div class="content">
            <h2>Password Reset</h2>
            <p>A password reset has been requested for your account.</p>
            
            <div class="credentials">
                <strong>Username:</strong> {username}<br>
                <strong>Temporary Password:</strong> {temporary_password}
            </div>
            
            <div class="warning-box">
                <strong>⚠️ Important:</strong> This temporary password is valid for one use only. You will be required to create a new password upon your first login.
            </div>
            
            <h3>Next Steps</h3>
            <ol>
                <li>Click the button below to access the login page</li>
                <li>Enter your username and the temporary password above</li>
                <li>Create a new secure password when prompted</li>
            </ol>
            
            <a href="{login_url}" class="button">Log In to O.A.S.I.S.</a>
            
            <p><strong>Didn't request a password reset?</strong><br>
            If you didn't request this password reset, please contact your system administrator immediately.</p>
        </div>
        <div class="footer">
            <p>This is an automated message from O.A.S.I.S. Please do not reply to this email.</p>
        </div>
    </div>
</body>
</html>
"""

        text_body = f"""
O.A.S.I.S. Password Reset

A password reset has been requested for your account.

Username: {username}
Temporary Password: {temporary_password}

IMPORTANT: This temporary password is valid for one use only. You will be required to create a new password upon login.

To reset your password:
1. Visit: {login_url}
2. Log in with the credentials above
3. Create a new secure password when prompted

Didn't request a password reset? Contact your system administrator immediately.

---
This is an automated message from O.A.S.I.S.
"""

        return self.send_email(to_email, subject, html_body, text_body)


async def get_email_service(pg_pool) -> Optional[EmailService]:
    """
    Factory function to create EmailService from database configuration

    Args:
        pg_pool: asyncpg connection pool

    Returns:
        EmailService instance or None if not configured
    """
    async with pg_pool.acquire() as conn:
        row = await conn.fetchrow("SELECT value FROM system_config WHERE key = 'smtp_config'")

        if not row:
            return None

        value = row["value"]
        if isinstance(value, str):
            import json

            value = json.loads(value)

        if not value.get("enabled", False):
            return None

        return EmailService(value)
