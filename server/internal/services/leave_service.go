package services

import (
	"errors"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"gorm.io/gorm"
)

type LeaveService struct {
	leaveRepo *repository.LeaveRepository
}

func NewLeaveService(leaveRepo *repository.LeaveRepository) *LeaveService {
	return &LeaveService{
		leaveRepo: leaveRepo,
	}
}

// GetAllLeaves mendapatkan semua leaves user
func (s *LeaveService) GetAllLeaves(userID string) ([]models.LeaveResponse, error) {
	leaves, err := s.leaveRepo.FindByUserID(userID)
	if err != nil {
		return nil, err
	}

	responses := make([]models.LeaveResponse, len(leaves))
	for i, leave := range leaves {
		responses[i] = leave.ToResponse()
	}

	return responses, nil
}

// GetUpcomingLeaves mendapatkan leaves yang akan datang
func (s *LeaveService) GetUpcomingLeaves(userID string) ([]models.LeaveResponse, error) {
	leaves, err := s.leaveRepo.FindUpcoming(userID)
	if err != nil {
		return nil, err
	}

	responses := make([]models.LeaveResponse, len(leaves))
	for i, leave := range leaves {
		responses[i] = leave.ToResponse()
	}

	return responses, nil
}

// GetPastLeaves mendapatkan leaves yang sudah lewat
func (s *LeaveService) GetPastLeaves(userID string) ([]models.LeaveResponse, error) {
	leaves, err := s.leaveRepo.FindPast(userID)
	if err != nil {
		return nil, err
	}

	responses := make([]models.LeaveResponse, len(leaves))
	for i, leave := range leaves {
		responses[i] = leave.ToResponse()
	}

	return responses, nil
}

// GetLeavesByMonth mendapatkan leaves dalam bulan tertentu
func (s *LeaveService) GetLeavesByMonth(userID string, year int, month time.Month) ([]models.LeaveResponse, error) {
	leaves, err := s.leaveRepo.FindByMonth(userID, year, month)
	if err != nil {
		return nil, err
	}

	responses := make([]models.LeaveResponse, len(leaves))
	for i, leave := range leaves {
		responses[i] = leave.ToResponse()
	}

	return responses, nil
}

// CreateLeave membuat leave baru
func (s *LeaveService) CreateLeave(userID string, date time.Time, reason string) (*models.LeaveResponse, error) {
	// Check if leave already exists on this date
	exists, err := s.leaveRepo.IsLeaveOnDate(userID, date)
	if err != nil {
		return nil, err
	}

	if exists {
		return nil, errors.New("leave already exists on this date")
	}

	leave := &models.Leave{
		UserID: userID,
		Date:   date,
		Reason: reason,
	}

	if err := s.leaveRepo.Create(leave); err != nil {
		return nil, err
	}

	response := leave.ToResponse()
	return &response, nil
}

// UpdateLeave mengupdate leave
func (s *LeaveService) UpdateLeave(leaveID, userID string, date time.Time, reason string) (*models.LeaveResponse, error) {
	// Find existing leave
	leave, err := s.leaveRepo.FindByID(leaveID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("leave not found")
		}
		return nil, err
	}

	// Verify ownership
	if leave.UserID != userID {
		return nil, errors.New("unauthorized to update this leave")
	}

	// Update fields
	leave.Date = date
	leave.Reason = reason

	if err := s.leaveRepo.Update(leave); err != nil {
		return nil, err
	}

	response := leave.ToResponse()
	return &response, nil
}

// DeleteLeave menghapus leave
func (s *LeaveService) DeleteLeave(leaveID, userID string) error {
	// Verify leave exists and belongs to user
	leave, err := s.leaveRepo.FindByID(leaveID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("leave not found")
		}
		return err
	}

	if leave.UserID != userID {
		return errors.New("unauthorized to delete this leave")
	}

	return s.leaveRepo.Delete(leaveID, userID)
}

// GetUpcomingCount mendapatkan jumlah leaves yang akan datang
func (s *LeaveService) GetUpcomingCount(userID string) (int64, error) {
	return s.leaveRepo.GetUpcomingCount(userID)
}
