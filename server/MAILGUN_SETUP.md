# Mailgun SMTP Setup Guide for Workradar
# Email Service Configuration untuk Password Reset & Notifications

## 📋 Overview

Mailgun dipilih sebagai SMTP provider karena:
- ✅ Fitur lengkap (analytics, templates, webhooks)
- ✅ Free tier generous (5,000 emails/month untuk 3 bulan pertama)
- ✅ API & SMTP support
- ✅ Excellent deliverability
- ✅ Easy domain verification

## 🚀 Setup Steps

### 1. Buat Akun Mailgun

1. Kunjungi https://www.mailgun.com/
2. Click "Start Sending" atau "Sign Up"
3. Isi form registrasi
4. Verify email Anda

### 2. Add & Verify Domain

**Option A: Subdomain (Recommended untuk testing)**
- Gunakan subdomain seperti `mg.workradar.com`
- Tidak mempengaruhi email domain utama

**Option B: Root Domain**
- Gunakan `workradar.com` langsung
- Lebih profesional untuk production

#### Steps:
1. Login ke Mailgun Dashboard
2. Go to **Sending** → **Domains**
3. Click **Add New Domain**
4. Enter domain: `mg.workradar.com` (atau domain Anda)
5. Pilih region: **US** atau **EU**

### 3. Configure DNS Records

Mailgun akan memberikan DNS records yang perlu ditambahkan:

```
# TXT Record untuk SPF
Type: TXT
Name: mg.workradar.com
Value: v=spf1 include:mailgun.org ~all

# TXT Record untuk DKIM
Type: TXT
Name: smtp._domainkey.mg.workradar.com
Value: k=rsa; p=MIGfMA0GCS... (dari Mailgun Dashboard)

# MX Records (untuk receiving - optional)
Type: MX
Name: mg.workradar.com
Priority: 10
Value: mxa.mailgun.org

Type: MX
Name: mg.workradar.com
Priority: 10
Value: mxb.mailgun.org

# CNAME untuk tracking (optional)
Type: CNAME
Name: email.mg.workradar.com
Value: mailgun.org
```

### 4. Verify Domain

1. Setelah DNS records ditambahkan, tunggu propagasi (5-10 menit)
2. Di Mailgun Dashboard, click **Verify DNS Settings**
3. Pastikan semua checks ✅ hijau

### 5. Get SMTP Credentials

1. Go to **Sending** → **Domain Settings** → **SMTP credentials**
2. Default credentials:
   - **SMTP Server**: `smtp.mailgun.org`
   - **Port**: `587` (TLS) atau `465` (SSL)
   - **Username**: `postmaster@mg.workradar.com`
   - **Password**: (generated atau create new)

3. Untuk create new SMTP user:
   - Click **Manage SMTP credentials**
   - Click **Add new SMTP user**
   - Enter login (e.g., `workradar@mg.workradar.com`)
   - Copy generated password (SIMPAN! tidak bisa dilihat lagi)

### 6. Configure Workradar Backend

Edit file `.env` atau `.env.production`:

```bash
# ========================================
# SMTP EMAIL CONFIGURATION - MAILGUN
# ========================================
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USERNAME=postmaster@mg.workradar.com
SMTP_PASSWORD=your-mailgun-smtp-password-here
SMTP_FROM_NAME=Workradar
SMTP_FROM_EMAIL=noreply@mg.workradar.com
```

### 7. Test Email Sending

#### Via API (Recommended untuk testing):

```powershell
# Test via Workradar API - Forgot Password
curl -X POST http://localhost:8080/api/auth/forgot-password `
  -H "Content-Type: application/json" `
  -d '{"email": "your-test-email@gmail.com"}'
```

#### Via SMTP directly:

```powershell
# Using PowerShell
$smtp = New-Object System.Net.Mail.SmtpClient("smtp.mailgun.org", 587)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential("postmaster@mg.workradar.com", "your-password")
$msg = New-Object System.Net.Mail.MailMessage
$msg.From = "noreply@mg.workradar.com"
$msg.To.Add("your-email@gmail.com")
$msg.Subject = "Test Email from Workradar"
$msg.Body = "This is a test email from Workradar via Mailgun."
$smtp.Send($msg)
```

## 📊 Mailgun Dashboard Features

### Email Analytics
- Track sent/delivered/opened/clicked
- Bounce rate monitoring
- Complaint tracking

### Logs & Events
- Real-time email logs
- Delivery events
- Error debugging

### Suppressions
- Manage unsubscribes
- Bounce management
- Complaint handling

### Templates (Optional)
- Create reusable email templates
- HTML editor
- Variable substitution

## 🔧 Troubleshooting

### Email tidak terkirim

1. **Check credentials**: Pastikan username/password benar
2. **Check domain verification**: Semua DNS records harus verified
3. **Check logs di Mailgun Dashboard**: Sending → Logs
4. **Check spam folder**: Email mungkin masuk spam

### Domain verification gagal

1. **DNS propagation**: Tunggu 24-48 jam untuk propagasi penuh
2. **Check DNS records**: Gunakan tool seperti https://mxtoolbox.com/
3. **TTL**: Set TTL rendah (300) untuk faster propagation

### Rate limiting

- Free tier: 100 emails/hour
- Upgrade untuk higher limits
- Implement queue untuk bulk sending

## 💰 Pricing

### Free Tier (FLEX)
- 5,000 emails/month free (3 bulan pertama)
- Setelah itu: Pay as you go

### Foundation
- $35/month
- 50,000 emails included
- Dedicated IP available

### Growth
- $80/month
- 100,000 emails included
- Priority support

## 📝 Production Checklist

- [ ] Domain verified dengan semua DNS records
- [ ] DKIM signing enabled
- [ ] SPF record configured
- [ ] Test email sent successfully
- [ ] Credentials stored securely (not in git)
- [ ] Monitoring email deliverability
- [ ] Bounce handling configured
- [ ] Unsubscribe mechanism (for marketing emails)

## 🔗 Useful Links

- [Mailgun Documentation](https://documentation.mailgun.com/)
- [SMTP Quickstart](https://documentation.mailgun.com/en/latest/quickstart-sending.html#send-via-smtp)
- [Domain Verification Guide](https://documentation.mailgun.com/en/latest/user_manual.html#verifying-your-domain)
- [Troubleshooting](https://documentation.mailgun.com/en/latest/best_practices.html)

## 🆘 Support

- Email: support@mailgun.com
- Documentation: https://documentation.mailgun.com/
- Status: https://status.mailgun.com/
