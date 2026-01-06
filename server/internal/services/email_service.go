package services

import (
	"bytes"
	"fmt"
	"html/template"
	"log"
	"net/smtp"
	"strconv"

	"github.com/workradar/server/internal/config"
)

// EmailService handles all email sending operations
type EmailService struct {
	host      string
	port      string
	username  string
	password  string
	fromName  string
	fromEmail string
}

// NewEmailService creates a new email service instance
func NewEmailService() *EmailService {
	return &EmailService{
		host:      config.AppConfig.SMTPHost,
		port:      config.AppConfig.SMTPPort,
		username:  config.AppConfig.SMTPUsername,
		password:  config.AppConfig.SMTPPassword,
		fromName:  config.AppConfig.SMTPFromName,
		fromEmail: config.AppConfig.SMTPFromEmail,
	}
}

// IsConfigured checks if SMTP is properly configured
func (s *EmailService) IsConfigured() bool {
	return s.username != "" && s.password != ""
}

// SendVerificationCode sends password reset verification code via email
func (s *EmailService) SendVerificationCode(toEmail, code string) error {
	if !s.IsConfigured() {
		log.Println("⚠️ SMTP not configured, skipping email send")
		return nil // Return nil untuk development mode
	}

	subject := "Workradar - Kode Verifikasi Reset Password"

	// HTML email template
	htmlTemplate := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 0;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
                    <!-- Header -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); padding: 40px; border-radius: 16px 16px 0 0; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: 700;">
                                📋 Workradar
                            </h1>
                            <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 14px;">
                                Task Management & Productivity App
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                        <td style="padding: 40px;">
                            <h2 style="color: #1f2937; margin: 0 0 20px 0; font-size: 22px;">
                                Reset Password
                            </h2>
                            <p style="color: #6b7280; line-height: 1.6; margin: 0 0 30px 0;">
                                Kami menerima permintaan untuk reset password akun Workradar Anda. 
                                Gunakan kode verifikasi di bawah ini untuk melanjutkan:
                            </p>
                            
                            <!-- Verification Code Box -->
                            <div style="background: linear-gradient(135deg, #EEF2FF 0%, #E0E7FF 100%); border-radius: 12px; padding: 30px; text-align: center; margin: 0 0 30px 0;">
                                <p style="color: #6366F1; font-size: 14px; margin: 0 0 10px 0; text-transform: uppercase; letter-spacing: 1px;">
                                    Kode Verifikasi
                                </p>
                                <h1 style="color: #4F46E5; font-size: 42px; letter-spacing: 8px; margin: 0; font-weight: 700;">
                                    {{.Code}}
                                </h1>
                            </div>
                            
                            <!-- Warning -->
                            <div style="background-color: #FEF3C7; border-left: 4px solid #F59E0B; padding: 15px; border-radius: 0 8px 8px 0; margin: 0 0 30px 0;">
                                <p style="color: #92400E; margin: 0; font-size: 14px;">
                                    ⚠️ <strong>Penting:</strong> Kode ini akan kadaluarsa dalam <strong>15 menit</strong>. 
                                    Jangan bagikan kode ini kepada siapapun.
                                </p>
                            </div>
                            
                            <p style="color: #6b7280; line-height: 1.6; margin: 0;">
                                Jika Anda tidak meminta reset password, abaikan email ini. 
                                Akun Anda tetap aman.
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f9fafb; padding: 30px; border-radius: 0 0 16px 16px; text-align: center;">
                            <p style="color: #9ca3af; font-size: 12px; margin: 0 0 10px 0;">
                                Email ini dikirim otomatis oleh Workradar. Mohon jangan membalas email ini.
                            </p>
                            <p style="color: #9ca3af; font-size: 12px; margin: 0;">
                                © 2026 Workradar. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
`

	// Parse template
	tmpl, err := template.New("email").Parse(htmlTemplate)
	if err != nil {
		return fmt.Errorf("failed to parse email template: %w", err)
	}

	// Execute template with data
	var body bytes.Buffer
	data := struct {
		Code string
	}{
		Code: code,
	}
	if err := tmpl.Execute(&body, data); err != nil {
		return fmt.Errorf("failed to execute email template: %w", err)
	}

	// Send email
	return s.sendHTML(toEmail, subject, body.String())
}

// SendWelcomeEmail sends welcome email to new users
func (s *EmailService) SendWelcomeEmail(toEmail, userName string) error {
	if !s.IsConfigured() {
		log.Println("⚠️ SMTP not configured, skipping welcome email")
		return nil
	}

	subject := "Selamat Datang di Workradar! 🎉"

	htmlTemplate := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 0;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); padding: 40px; border-radius: 16px 16px 0 0; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎉 Selamat Datang!</h1>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <h2 style="color: #1f2937; margin: 0 0 20px 0;">Halo, {{.UserName}}!</h2>
                            <p style="color: #6b7280; line-height: 1.6;">
                                Terima kasih telah bergabung dengan <strong>Workradar</strong>. 
                                Kami senang Anda memilih kami untuk membantu meningkatkan produktivitas Anda!
                            </p>
                            <p style="color: #6b7280; line-height: 1.6;">
                                Mulai sekarang, Anda dapat:
                            </p>
                            <ul style="color: #6b7280; line-height: 1.8;">
                                <li>📋 Membuat dan mengelola tugas harian</li>
                                <li>📊 Memantau beban kerja dengan grafik</li>
                                <li>🔔 Menerima pengingat otomatis</li>
                                <li>📅 Mengatur kalender personal</li>
                            </ul>
                            <p style="color: #6b7280; line-height: 1.6; margin-top: 30px;">
                                Selamat berproduktivitas! 💪
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td style="background-color: #f9fafb; padding: 30px; border-radius: 0 0 16px 16px; text-align: center;">
                            <p style="color: #9ca3af; font-size: 12px; margin: 0;">
                                © 2026 Workradar. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
`

	tmpl, err := template.New("welcome").Parse(htmlTemplate)
	if err != nil {
		return fmt.Errorf("failed to parse welcome template: %w", err)
	}

	var body bytes.Buffer
	data := struct {
		UserName string
	}{
		UserName: userName,
	}
	if err := tmpl.Execute(&body, data); err != nil {
		return fmt.Errorf("failed to execute welcome template: %w", err)
	}

	return s.sendHTML(toEmail, subject, body.String())
}

// SendVIPUpgradeEmail sends confirmation email after VIP upgrade
func (s *EmailService) SendVIPUpgradeEmail(toEmail, userName, plan string) error {
	if !s.IsConfigured() {
		log.Println("⚠️ SMTP not configured, skipping VIP upgrade email")
		return nil
	}

	subject := "Selamat! Anda sekarang VIP Member 👑"

	htmlTemplate := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 0;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%); padding: 40px; border-radius: 16px 16px 0 0; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 28px;">👑 VIP Member</h1>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <h2 style="color: #1f2937; margin: 0 0 20px 0;">Halo, {{.UserName}}!</h2>
                            <p style="color: #6b7280; line-height: 1.6;">
                                Selamat! Akun Anda telah berhasil di-upgrade ke <strong>VIP Member</strong> 
                                dengan paket <strong>{{.Plan}}</strong>.
                            </p>
                            <p style="color: #6b7280; line-height: 1.6;">
                                Sekarang Anda dapat menikmati fitur eksklusif:
                            </p>
                            <ul style="color: #6b7280; line-height: 1.8;">
                                <li>📊 Grafik Mingguan & Bulanan</li>
                                <li>🔄 Pengaturan Repeat Task dengan End Date</li>
                                <li>⏰ Pilihan Reminder Fleksibel (5/10/15/30 menit)</li>
                                <li>☀️ Integrasi Cuaca</li>
                                <li>💪 Rekomendasi Kesehatan</li>
                            </ul>
                            <p style="color: #6b7280; line-height: 1.6; margin-top: 30px;">
                                Terima kasih atas dukungan Anda! 🙏
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td style="background-color: #f9fafb; padding: 30px; border-radius: 0 0 16px 16px; text-align: center;">
                            <p style="color: #9ca3af; font-size: 12px; margin: 0;">
                                © 2026 Workradar. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
`

	tmpl, err := template.New("vip").Parse(htmlTemplate)
	if err != nil {
		return fmt.Errorf("failed to parse VIP template: %w", err)
	}

	var body bytes.Buffer
	data := struct {
		UserName string
		Plan     string
	}{
		UserName: userName,
		Plan:     plan,
	}
	if err := tmpl.Execute(&body, data); err != nil {
		return fmt.Errorf("failed to execute VIP template: %w", err)
	}

	return s.sendHTML(toEmail, subject, body.String())
}

// sendHTML sends an HTML email using SMTP
func (s *EmailService) sendHTML(to, subject, htmlBody string) error {
	// Construct email headers
	headers := make(map[string]string)
	headers["From"] = fmt.Sprintf("%s <%s>", s.fromName, s.fromEmail)
	headers["To"] = to
	headers["Subject"] = subject
	headers["MIME-Version"] = "1.0"
	headers["Content-Type"] = "text/html; charset=UTF-8"

	// Build message
	var message bytes.Buffer
	for k, v := range headers {
		message.WriteString(fmt.Sprintf("%s: %s\r\n", k, v))
	}
	message.WriteString("\r\n")
	message.WriteString(htmlBody)

	// SMTP authentication
	auth := smtp.PlainAuth("", s.username, s.password, s.host)

	// Parse port
	port, _ := strconv.Atoi(s.port)
	addr := fmt.Sprintf("%s:%d", s.host, port)

	// Send email
	err := smtp.SendMail(addr, auth, s.fromEmail, []string{to}, message.Bytes())
	if err != nil {
		log.Printf("❌ Failed to send email to %s: %v", to, err)
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("✅ Email sent successfully to %s", to)
	return nil
}
