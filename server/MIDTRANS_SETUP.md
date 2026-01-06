# Midtrans Payment Integration - Setup Guide

## Configuration

### 1. Get Midtrans Credentials

1. Register at [Midtrans Dashboard](https://dashboard.midtrans.com/)
2. Go to Settings → Access Keys
3. Copy your **Server Key** and **Client Key**
4. Use **Sandbox** keys for testing

### 2. Update Environment Variables

Add to your `.env` file:

```bash
MIDTRANS_SERVER_KEY=SB-Mid-server-xxxxxxxxxxxxxxx
MIDTRANS_CLIENT_KEY=SB-Mid-client-xxxxxxxxxxxxxxx
MIDTRANS_IS_PRODUCTION=false
```

### 3. Webhook Configuration

Set Midtrans webhook URL in Dashboard → Settings → Configuration:

```
https://your-domain.com/api/webhooks/midtrans
```

For local testing, use ngrok or similar:
```
https://xxxx-xx-xx-xxx-xxx.ngrok.io/api/webhooks/midtrans
```

## API Endpoints

### Create Payment
```http
POST /api/payments/create
Authorization: Bearer {token}
Content-Type: application/json

{
  "plan_type": "monthly"  // or "yearly"
}

Response:
{
  "token": "snap-token-xxxx",
  "redirect_url": "https://app.sandbox.midtrans.com/snap/v3/..."
}
```

### Get Payment Status
```http
GET /api/payments/:order_id
Authorization: Bearer {token}

Response:
{
  "status": "success",
  "data": {
    "order_id": "ORDER-xxx",
    "status": "settlement",
    "amount": 50000,
    ...
  }
}
```

### Get Payment History
```http
GET /api/payments/history
Authorization: Bearer {token}

Response:
{
  "status": "success",
  "data": [...]
}
```

### Cancel Payment
```http
POST /api/payments/:order_id/cancel
Authorization: Bearer {token}

Response:
{
  "status": "success",
  "message": "Payment cancelled successfully"
}
```

### Webhook (Public - Called by Midtrans)
```http
POST /api/webhooks/midtrans
Content-Type: application/json

{
  "order_id": "ORDER-xxx",
  "transaction_status": "settlement",
  ...
}
```

## Payment Flow

1. **Frontend**: User selects VIP plan → calls `/api/payments/create`
2. **Backend**: Creates transaction → gets Snap Token from Midtrans
3. **Frontend**: Redirects to Midtrans payment page with token
4. **User**: Completes payment on Midtrans
5. **Midtrans**: Sends webhook to `/api/webhooks/midtrans`
6. **Backend**: 
   - Updates transaction status
   - Upgrades user to VIP (if settlement)
   - Sends bot message notification
7. **Frontend**: Checks payment status → shows success/failed

## Transaction Statuses

- `pending`: Payment created, awaiting payment
- `settlement`: Payment successful
- `cancel`: Payment cancelled by user
- `deny`: Payment denied by bank/gateway
- `expire`: Payment expired (not completed in time)

## Testing

### Test Cards (Sandbox)

**Success:**
- Card: `4811 1111 1111 1114`
- CVV: `123`
- Exp: Any future date

**Failed:**
- Card: `4011 1111 1111 1112`

**Pending:**
- Card: `4611 1111 1111 1113`

## Production Deployment

1. Get Production keys from Midtrans Dashboard
2. Update `.env`:
   ```bash
   MIDTRANS_SERVER_KEY=Mid-server-xxxxxxxxxxxxxxx
   MIDTRANS_CLIENT_KEY=Mid-client-xxxxxxxxxxxxxxx
   MIDTRANS_IS_PRODUCTION=true
   ```
3. Update webhook URL to production domain
4. Test thoroughly before going live
