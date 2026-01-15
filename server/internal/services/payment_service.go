package services

import (
	"crypto/sha512"
	"encoding/hex"
	"errors"
	"log"

	"github.com/google/uuid"
	"github.com/midtrans/midtrans-go"
	"github.com/midtrans/midtrans-go/coreapi"
	"github.com/midtrans/midtrans-go/snap"
	"github.com/workradar/server/internal/config"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
)

type PaymentService struct {
	transactionRepo   *repository.TransactionRepository
	userRepo          *repository.UserRepository
	subService        *SubscriptionService
	botMessageService *BotMessageService
	snapClient        snap.Client
	apiClient         coreapi.Client
}

func NewPaymentService(
	transactionRepo *repository.TransactionRepository,
	userRepo *repository.UserRepository,
	subService *SubscriptionService,
	botMessageService *BotMessageService,
) *PaymentService {
	// Initialize Midtrans Snap Client
	var s snap.Client
	var c coreapi.Client

	// Validate server key
	if config.AppConfig.MidtransServerKey == "" {
		log.Fatal("MIDTRANS_SERVER_KEY is not set in environment variables")
	}

	// Set environment based on production flag
	env := midtrans.Sandbox
	if config.AppConfig.MidtransIsProduction {
		env = midtrans.Production
	}
	
	// Debug logging (masked for security)
	serverKeyPrefix := "unknown"
	if len(config.AppConfig.MidtransServerKey) > 10 {
		serverKeyPrefix = config.AppConfig.MidtransServerKey[:10]
	}
	log.Printf("🔧 Midtrans Config - Environment: %v, IsProduction: %v, ServerKey prefix: %s..., Key length: %d", 
		env, config.AppConfig.MidtransIsProduction, serverKeyPrefix, len(config.AppConfig.MidtransServerKey))
	
	// Initialize clients with proper environment
	s.New(config.AppConfig.MidtransServerKey, env)
	c.New(config.AppConfig.MidtransServerKey, env)
	
	log.Printf("✅ Midtrans initialized in %v mode", env)

	return &PaymentService{
		transactionRepo:   transactionRepo,
		userRepo:          userRepo,
		subService:        subService,
		botMessageService: botMessageService,
		snapClient:        s,
		apiClient:         c,
	}
}

// CreateSnapToken creates a transaction and returns Snap Token, Redirect URL, and Order ID
func (s *PaymentService) CreateSnapToken(userID string, planType models.PlanType) (string, string, string, error) {
	// 1. Validate User
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		log.Printf("Error finding user %s: %v", userID, err)
		return "", "", "", errors.New("user not found")
	}

	// 2. Determine Amount
	var amount float64
	var planName string
	if planType == models.PlanTypeMonthly {
		amount = models.PriceMonthly
		planName = "Workradar VIP (Monthly)"
	} else if planType == models.PlanTypeYearly {
		amount = models.PriceYearly
		planName = "Workradar VIP (Yearly)"
	} else {
		log.Printf("Invalid plan type: %s", planType)
		return "", "", "", errors.New("invalid plan type")
	}

	// 3. Generate Order ID with UUID (prevent collision)
	orderID := "ORDER-" + uuid.New().String()

	// 4. Create Snap Request
	req := &snap.Request{
		TransactionDetails: midtrans.TransactionDetails{
			OrderID:  orderID,
			GrossAmt: int64(amount),
		},
		CreditCard: &snap.CreditCardDetails{
			Secure: true,
		},
		CustomerDetail: &midtrans.CustomerDetails{
			FName: user.Username,
			Email: user.Email,
		},
		Items: &[]midtrans.ItemDetails{
			{
				ID:    string(planType),
				Name:  planName,
				Price: int64(amount),
				Qty:   1,
			},
		},
	}

	// 5. Request Snap Token
	log.Printf("📤 Creating Midtrans transaction - OrderID: %s, Amount: %.0f, User: %s (%s)", orderID, amount, user.Username, user.Email)
	snapResp, err := s.snapClient.CreateTransaction(req)

	// Check response validity FIRST (fix for Go interface nil gotcha)
	// Midtrans SDK sometimes returns non-nil error interface with nil value
	// If response is valid with token, treat as success regardless of error
	if snapResp == nil {
		log.Printf("❌ Midtrans returned nil response - OrderID: %s, Error: %v", orderID, err)
		return "", "", "", errors.New("payment gateway returned nil response")
	}

	if snapResp.Token == "" {
		log.Printf("❌ Midtrans returned empty token - OrderID: %s, Error: %v", orderID, err)
		return "", "", "", errors.New("payment gateway returned empty token")
	}

	// If we have valid response with token, transaction is successful
	log.Printf("✅ Midtrans transaction SUCCESS - OrderID: %s, Token: %s, RedirectURL: %s", orderID, snapResp.Token, snapResp.RedirectURL)

	// 6. Save Transaction to DB
	trx := &models.Transaction{
		OrderID:   orderID,
		UserID:    userID,
		PlanType:  planType,
		Amount:    amount,
		Status:    models.TransactionStatusPending,
		SnapToken: snapResp.Token,
	}

	if err := s.transactionRepo.Create(trx); err != nil {
		return "", "", "", err
	}

	return snapResp.Token, snapResp.RedirectURL, orderID, nil
}

// HandleNotification processes Midtrans webhook
func (s *PaymentService) HandleNotification(notificationPayload map[string]interface{}) error {
	// 1. Get Order ID
	orderID, exists := notificationPayload["order_id"].(string)
	if !exists {
		return errors.New("invalid notification payload")
	}

	log.Printf("📨 Processing webhook for order: %s", orderID)

	// 2. Find Transaction in DB first (for idempotency check)
	trx, errRepo := s.transactionRepo.FindByOrderID(orderID)
	if errRepo != nil {
		log.Printf("❌ Transaction not found in DB: %s", orderID)
		return errRepo
	}

	// 3. IDEMPOTENCY CHECK: Skip if already settled
	if trx.Status == models.TransactionStatusSettlement {
		log.Printf("⏭️  Transaction %s already settled, skipping webhook processing", orderID)
		return nil // Return OK so Midtrans doesn't retry
	}

	// 4. Check Transaction Status from Midtrans
	transactionStatusResp, err := s.apiClient.CheckTransaction(orderID)
	if err != nil {
		log.Printf("❌ Error checking transaction with Midtrans: %v", err)
		return err
	}

	if transactionStatusResp == nil {
		log.Printf("❌ Transaction not found in Midtrans: %s", orderID)
		return errors.New("transaction not found")
	}

	// 5. Update Status based on Midtrans Response
	var status models.TransactionStatus
	transactionStatus := transactionStatusResp.TransactionStatus
	fraudStatus := transactionStatusResp.FraudStatus

	if transactionStatus == "capture" {
		if fraudStatus == "challenge" {
			status = models.TransactionStatusPending // Challenge pending
		} else if fraudStatus == "accept" {
			status = models.TransactionStatusSettlement
		}
	} else if transactionStatus == "settlement" {
		status = models.TransactionStatusSettlement
	} else if transactionStatus == "deny" {
		status = models.TransactionStatusDeny
	} else if transactionStatus == "cancel" || transactionStatus == "expire" {
		status = models.TransactionStatusCancel
	} else if transactionStatus == "pending" {
		status = models.TransactionStatusPending
	} else {
		status = models.TransactionStatusPending
	}

	log.Printf("💳 Transaction %s status: %s → %s", orderID, transactionStatus, status)

	// Update transaction status
	if err := s.transactionRepo.UpdateStatus(orderID, status); err != nil {
		return err
	}

	// 6. If Success (Settlement), Activate Subscription & Send Success Message
	if status == models.TransactionStatusSettlement {
		log.Printf("Payment success for order: %s. Upgrading user...", orderID)

		// Determine payment type from notification
		paymentType, _ := notificationPayload["payment_type"].(string)

		// Update payment method in transaction
		if paymentType != "" {
			_ = s.transactionRepo.UpdatePaymentMethod(orderID, paymentType)
		}

		// Create Subscription & Upgrade User
		_, err := s.subService.CreateSubscription(trx.UserID, trx.PlanType, paymentType, orderID)
		if err != nil {
			log.Printf("Failed to upgrade subscription for order %s: %v", orderID, err)
			return err
		}

		// Send success bot message
		if s.botMessageService != nil {
			if err := s.botMessageService.SendPaymentSuccessMessage(trx.UserID, trx.Amount); err != nil {
				log.Printf("Warning: Failed to send payment success message: %v", err)
				// Don't return error, payment was successful
			}
		}
	} else if status == models.TransactionStatusDeny || status == models.TransactionStatusCancel || status == models.TransactionStatusExpire {
		// Send failure bot message for denied, cancelled, or expired payments
		if s.botMessageService != nil {
			reason := "Pembayaran tidak dapat diproses"
			if status == models.TransactionStatusDeny {
				reason = "Pembayaran ditolak oleh gateway"
			} else if status == models.TransactionStatusCancel {
				reason = "Pembayaran dibatalkan"
			} else if status == models.TransactionStatusExpire {
				reason = "Pembayaran sudah kadaluarsa"
			}
			if err := s.botMessageService.SendPaymentFailedMessage(trx.UserID, reason); err != nil {
				log.Printf("Warning: Failed to send payment failed message: %v", err)
			}
		}
	}

	return nil
}

// GetPaymentHistory retrieves all transactions for a user
func (s *PaymentService) GetPaymentHistory(userID string) ([]models.Transaction, error) {
	return s.transactionRepo.FindByUserID(userID)
}

// CancelTransaction cancels a pending transaction
func (s *PaymentService) CancelTransaction(orderID string) error {
	// Check if transaction exists and is pending
	trx, err := s.transactionRepo.FindByOrderID(orderID)
	if err != nil {
		return errors.New("transaction not found")
	}

	if trx.Status != models.TransactionStatusPending {
		return errors.New("only pending transactions can be cancelled")
	}

	// Update status to cancelled
	return s.transactionRepo.UpdateStatus(orderID, models.TransactionStatusCancel)
}

// GetTransactionByOrderID retrieves a transaction by order ID
func (s *PaymentService) GetTransactionByOrderID(orderID string) (*models.Transaction, error) {
	return s.transactionRepo.FindByOrderID(orderID)
}

// VerifyNotificationSignature verifies the signature from Midtrans webhook
// This prevents fake webhook attacks
func (s *PaymentService) VerifyNotificationSignature(
	orderID string,
	statusCode string,
	grossAmount string,
	signatureKey string,
) bool {
	// Midtrans signature formula: SHA512(order_id + status_code + gross_amount + server_key)
	input := orderID + statusCode + grossAmount + config.AppConfig.MidtransServerKey
	hash := sha512.Sum512([]byte(input))
	calculatedSignature := hex.EncodeToString(hash[:])

	isValid := calculatedSignature == signatureKey
	if !isValid {
		log.Printf("❌ Invalid signature for order %s. Expected: %s, Got: %s",
			orderID, calculatedSignature[:32]+"...", signatureKey[:32]+"...")
	} else {
		log.Printf("✅ Valid signature for order %s", orderID)
	}
	return isValid
}
