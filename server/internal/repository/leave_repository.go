package repository

import (
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type LeaveRepository struct {
	db *gorm.DB
}

func NewLeaveRepository(db *gorm.DB) *LeaveRepository {
	return &LeaveRepository{db: db}
}

// Create membuat leave baru
func (r *LeaveRepository) Create(leave *models.Leave) error {
	return r.db.Create(leave).Error
}

// FindByUserID mendapatkan semua leaves user
func (r *LeaveRepository) FindByUserID(userID string) ([]models.Leave, error) {
	var leaves []models.Leave
	err := r.db.Where("user_id = ?", userID).Order("date DESC").Find(&leaves).Error
	return leaves, err
}

// FindByID mencari leave by ID
func (r *LeaveRepository) FindByID(id string) (*models.Leave, error) {
	var leave models.Leave
	err := r.db.First(&leave, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &leave, nil
}

// FindUpcoming mendapatkan leaves yang akan datang
func (r *LeaveRepository) FindUpcoming(userID string) ([]models.Leave, error) {
	var leaves []models.Leave
	today := time.Now().Truncate(24 * time.Hour)

	err := r.db.Where("user_id = ? AND date >= ?", userID, today).
		Order("date ASC").
		Find(&leaves).Error

	return leaves, err
}

// FindPast mendapatkan leaves yang sudah lewat
func (r *LeaveRepository) FindPast(userID string) ([]models.Leave, error) {
	var leaves []models.Leave
	today := time.Now().Truncate(24 * time.Hour)

	err := r.db.Where("user_id = ? AND date < ?", userID, today).
		Order("date DESC").
		Find(&leaves).Error

	return leaves, err
}

// FindByMonth mendapatkan leaves dalam bulan tertentu
func (r *LeaveRepository) FindByMonth(userID string, year int, month time.Month) ([]models.Leave, error) {
	var leaves []models.Leave

	startDate := time.Date(year, month, 1, 0, 0, 0, 0, time.UTC)
	endDate := startDate.AddDate(0, 1, -1)

	err := r.db.Where("user_id = ? AND date BETWEEN ? AND ?", userID, startDate, endDate).
		Order("date ASC").
		Find(&leaves).Error

	return leaves, err
}

// Update memperbarui leave
func (r *LeaveRepository) Update(leave *models.Leave) error {
	return r.db.Save(leave).Error
}

// Delete menghapus leave
func (r *LeaveRepository) Delete(id string, userID string) error {
	return r.db.Where("id = ? AND user_id = ?", id, userID).Delete(&models.Leave{}).Error
}

// IsLeaveOnDate mengecek apakah tanggal tertentu adalah leave day
func (r *LeaveRepository) IsLeaveOnDate(userID string, date time.Time) (bool, error) {
	var count int64
	err := r.db.Model(&models.Leave{}).
		Where("user_id = ? AND date = ?", userID, date).
		Count(&count).Error
	return count > 0, err
}

// GetUpcomingCount mendapatkan jumlah leaves yang akan datang
func (r *LeaveRepository) GetUpcomingCount(userID string) (int64, error) {
	var count int64
	today := time.Now().Truncate(24 * time.Hour)

	err := r.db.Model(&models.Leave{}).
		Where("user_id = ? AND date >= ?", userID, today).
		Count(&count).Error

	return count, err
}
