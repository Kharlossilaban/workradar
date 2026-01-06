package services

import (
	"errors"
	"fmt"
	"log"
	"time"

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
	s.New(config.AppConfig.MidtransServerKey, midtrans.Sandbox)
	if config.AppConfig.MidtransIsProduction {
		s.New(config.AppConfig.MidtransServerKey, midtrans.Production)
	}

	// Initialize Midtrans Core API Client (for checking status)
	var c coreapi.Client
	c.New(config.AppConfig.MidtransServerKey, midtrans.Sandbox)
	if config.AppConfig.MidtransIsProduction {
		c.New(config.AppConfig.MidtransServerKey, midtrans.Production)
	}

	return &PaymentService{
		transactionRepo:   transactionRepo,
		userRepo:          userRepo,
		subService:        subService,
		botMessageService: botMessageService,
		snapClient:        s,
		apiClient:         c,
	}
}

// CreateSnapToken creates a transaction and returns Snap Token
func (s *PaymentService) CreateSnapToken(userID string, planType models.PlanType) (string, string, error) {
	// 1. Validate User
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return "", "", errors.New("user not found")
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
		return "", "", errors.New("invalid plan type")
	}

	// 3. Generate Order ID
	// Use timestamp + random for unique ID
	orderID := "ORDER-" + userID[:8] + "-" + fmt.Sprintf("%d", time.Now().UnixNano())

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
	snapResp, err := s.snapClient.CreateTransaction(req)
	if err != nil {
		log.Printf("Midtrans Error: %v", err)
		return "", "", errors.New("payment gateway error")
	}

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
		return "", "", err
	}

	return snapResp.Token, snapResp.RedirectURL, nil
}

// HandleNotification processes Midtrans webhook
func (s *PaymentService) HandleNotification(notificationPayload map[string]interface{}) error {
	// 1. Get Order ID
	orderID, exists := notificationPayload["order_id"].(string)
	if !exists {
		return errors.New("invalid notification payload")
	}

	// 2. Check Transaction Status from Midtrans
	transactionStatusResp, err := s.apiClient.CheckTransaction(orderID)
	if err != nil {
		return err
	}

	if transactionStatusResp == nil {
		return errors.New("transaction not found")
	}

	// 3. Find Transaction in DB
	// 3. Find Transaction in DB
	trx, errRepo := s.transactionRepo.FindByOrderID(orderID)
	if errRepo != nil {
		return errRepo
	}

	// 4. Update Status based on Midtrans Response
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

	// Update transaction status
	if err := s.transactionRepo.UpdateStatus(orderID, status); err != nil {
		return err
	}

	// 5. If Success (Settlement), Activate Subscription & Send Success Message
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
