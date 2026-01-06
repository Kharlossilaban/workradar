package services

import (
	"errors"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"gorm.io/gorm"
)

type HolidayService struct {
	holidayRepo *repository.HolidayRepository
}

func NewHolidayService(holidayRepo *repository.HolidayRepository) *HolidayService {
	return &HolidayService{
		holidayRepo: holidayRepo,
	}
}

// GetAllHolidays mendapatkan semua holidays (national + user's personal)
func (s *HolidayService) GetAllHolidays(userID string) ([]models.HolidayResponse, error) {
	holidays, err := s.holidayRepo.FindAll(&userID)
	if err != nil {
		return nil, err
	}

	responses := make([]models.HolidayResponse, len(holidays))
	for i, holiday := range holidays {
		responses[i] = holiday.ToResponse()
	}

	return responses, nil
}

// GetHolidaysByDateRange mendapatkan holidays dalam rentang tanggal
func (s *HolidayService) GetHolidaysByDateRange(userID string, startDate, endDate time.Time) ([]models.HolidayResponse, error) {
	holidays, err := s.holidayRepo.FindByDateRange(&userID, startDate, endDate)
	if err != nil {
		return nil, err
	}

	responses := make([]models.HolidayResponse, len(holidays))
	for i, holiday := range holidays {
		responses[i] = holiday.ToResponse()
	}

	return responses, nil
}

// CreatePersonalHoliday membuat personal holiday baru
func (s *HolidayService) CreatePersonalHoliday(userID, name string, date time.Time, description *string) (*models.HolidayResponse, error) {
	holiday := &models.Holiday{
		UserID:      &userID,
		Name:        name,
		Date:        date,
		IsNational:  false,
		Description: description,
	}

	if err := s.holidayRepo.Create(holiday); err != nil {
		return nil, err
	}

	response := holiday.ToResponse()
	return &response, nil
}

// DeletePersonalHoliday menghapus personal holiday
func (s *HolidayService) DeletePersonalHoliday(holidayID, userID string) error {
	// Verify holiday exists and belongs to user
	holiday, err := s.holidayRepo.FindByID(holidayID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("holiday not found")
		}
		return err
	}

	// Check if it's a national holiday (cannot be deleted)
	if holiday.IsNational {
		return errors.New("cannot delete national holiday")
	}

	// Check if it belongs to the user
	if holiday.UserID == nil || *holiday.UserID != userID {
		return errors.New("unauthorized to delete this holiday")
	}

	return s.holidayRepo.Delete(holidayID, userID)
}

// IsHolidayOnDate mengecek apakah tanggal tertentu adalah holiday
func (s *HolidayService) IsHolidayOnDate(userID string, date time.Time) (bool, error) {
	return s.holidayRepo.IsHolidayOnDate(&userID, date)
}
