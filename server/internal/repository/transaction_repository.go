package repository

import (
	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type TransactionRepository struct {
	db *gorm.DB
}

func NewTransactionRepository(db *gorm.DB) *TransactionRepository {
	return &TransactionRepository{db: db}
}

// Create menyimpan transaksi baru
func (r *TransactionRepository) Create(transaction *models.Transaction) error {
	return r.db.Create(transaction).Error
}

// FindByOrderID mencari transaksi berdasarkan Order ID
func (r *TransactionRepository) FindByOrderID(orderID string) (*models.Transaction, error) {
	var transaction models.Transaction
	if err := r.db.Where("order_id = ?", orderID).First(&transaction).Error; err != nil {
		return nil, err
	}
	return &transaction, nil
}

// UpdateStatus memperbarui status transaksi
func (r *TransactionRepository) UpdateStatus(orderID string, status models.TransactionStatus) error {
	return r.db.Model(&models.Transaction{}).Where("order_id = ?", orderID).Update("status", status).Error
}

// UpdateSnapToken menyimpan snap token
func (r *TransactionRepository) UpdateSnapToken(orderID string, token string) error {
	return r.db.Model(&models.Transaction{}).Where("order_id = ?", orderID).Update("snap_token", token).Error
}

// FindByUserID mencari semua transaksi berdasarkan User ID
func (r *TransactionRepository) FindByUserID(userID string) ([]models.Transaction, error) {
	var transactions []models.Transaction
	err := r.db.Where("user_id = ?", userID).Order("created_at desc").Find(&transactions).Error
	return transactions, err
}

// UpdatePaymentMethod memperbarui payment method transaksi
func (r *TransactionRepository) UpdatePaymentMethod(orderID string, method string) error {
	return r.db.Model(&models.Transaction{}).Where("order_id = ?", orderID).Update("payment_method", method).Error
}

// FindPendingByUserID mencari semua transaksi pending berdasarkan User ID
func (r *TransactionRepository) FindPendingByUserID(userID string) ([]models.Transaction, error) {
	var transactions []models.Transaction
	err := r.db.Where("user_id = ? AND status = ?", userID, models.TransactionStatusPending).Order("created_at desc").Find(&transactions).Error
	return transactions, err
}
