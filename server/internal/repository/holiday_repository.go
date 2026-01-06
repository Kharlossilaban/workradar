package repository

import (
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type HolidayRepository struct {
	db *gorm.DB
}

func NewHolidayRepository(db *gorm.DB) *HolidayRepository {
	return &HolidayRepository{db: db}
}

// Create membuat holiday baru (personal)
func (r *HolidayRepository) Create(holiday *models.Holiday) error {
	return r.db.Create(holiday).Error
}

// FindAll mendapatkan semua holidays (national + user's personal)
func (r *HolidayRepository) FindAll(userID *string) ([]models.Holiday, error) {
	var holidays []models.Holiday
	query := r.db.Where("is_national = ?", true)

	if userID != nil {
		query = query.Or("user_id = ?", *userID)
	}

	err := query.Order("date ASC").Find(&holidays).Error
	return holidays, err
}

// FindByDateRange mendapatkan holidays dalam rentang tanggal
func (r *HolidayRepository) FindByDateRange(userID *string, startDate, endDate time.Time) ([]models.Holiday, error) {
	var holidays []models.Holiday
	query := r.db.Where("date BETWEEN ? AND ?", startDate, endDate)
	query = query.Where("is_national = ?", true)

	if userID != nil {
		query = query.Or("(user_id = ? AND date BETWEEN ? AND ?)", *userID, startDate, endDate)
	}

	err := query.Order("date ASC").Find(&holidays).Error
	return holidays, err
}

// FindByID mencari holiday by ID
func (r *HolidayRepository) FindByID(id string) (*models.Holiday, error) {
	var holiday models.Holiday
	err := r.db.First(&holiday, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &holiday, nil
}

// Delete menghapus personal holiday
func (r *HolidayRepository) Delete(id string, userID string) error {
	// Only allow deleting personal holidays (not national)
	return r.db.Where("id = ? AND user_id = ? AND is_national = ?", id, userID, false).
		Delete(&models.Holiday{}).Error
}

// IsHolidayOnDate mengecek apakah tanggal tertentu adalah holiday
func (r *HolidayRepository) IsHolidayOnDate(userID *string, date time.Time) (bool, error) {
	var count int64
	query := r.db.Model(&models.Holiday{}).Where("date = ?", date)
	query = query.Where("is_national = ?", true)

	if userID != nil {
		query = query.Or("(user_id = ? AND date = ?)", *userID, date)
	}

	err := query.Count(&count).Error
	return count > 0, err
}
