package services

import (
	"fmt"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
)

type BotMessageService struct {
	repo *repository.BotMessageRepository
}

func NewBotMessageService(repo *repository.BotMessageRepository) *BotMessageService {
	return &BotMessageService{repo: repo}
}

// SendMessage creates and saves a new bot message
func (s *BotMessageService) SendMessage(userID string, msgType models.MessageType, title, content string, metadata map[string]interface{}) (*models.BotMessage, error) {
	message := &models.BotMessage{
		UserID:    userID,
		Type:      msgType,
		Title:     title,
		Content:   content,
		Metadata:  metadata,
		IsRead:    false,
		CreatedAt: time.Now(),
	}

	if err := s.repo.Create(message); err != nil {
		return nil, err
	}

	return message, nil
}

func (s *BotMessageService) GetUserMessages(userID string) ([]models.BotMessage, error) {
	return s.repo.FindByUserID(userID)
}

func (s *BotMessageService) GetUnreadMessages(userID string) ([]models.BotMessage, error) {
	return s.repo.FindUnreadByUserID(userID)
}

func (s *BotMessageService) MarkAsRead(id string) error {
	return s.repo.MarkAsRead(id)
}

func (s *BotMessageService) MarkAllAsRead(userID string) error {
	return s.repo.MarkAllAsRead(userID)
}

func (s *BotMessageService) DeleteMessage(id string) error {
	return s.repo.DeleteByID(id)
}

func (s *BotMessageService) GetUnreadCount(userID string) (int64, error) {
	return s.repo.CountUnread(userID)
}

// --- Automated Message Helpers ---

func (s *BotMessageService) SendWelcomeMessage(userID string) error {
	title := "Selamat Datang, Member VIP! 🎉"
	content := "Terima kasih telah bergabung sebagai member VIP Workradar! \n" +
		"Anda sekarang dapat menikmati semua fitur premium termasuk:\n\n" +
		"✨ Grafik workload Weekly & Monthly\n" +
		"🌤️ Prakiraan cuaca real-time\n" +
		"📊 Statistik lengkap tugas Anda\n" +
		"🎯 Fitur-fitur eksklusif lainnya\n\n" +
		"Selamat bekerja lebih produktif!"

	_, err := s.SendMessage(userID, models.MessageTypeWelcome, title, content, nil)
	return err
}

func (s *BotMessageService) SendPaymentSuccessMessage(userID string, amount float64) error {
	title := "Pembayaran Berhasil! ✅"
	formattedAmount := fmt.Sprintf("%.0f", amount)
	// Simple formatting, can be improved to use thousands separator if needed

	content := fmt.Sprintf("Pembayaran VIP subscription sebesar Rp %s telah berhasil diproses.\n\n"+
		"Status VIP Anda sekarang aktif. Nikmati semua fitur premium!\n\n"+
		"Terima kasih atas kepercayaan Anda.", formattedAmount)

	metadata := map[string]interface{}{
		"amount": amount,
	}

	_, err := s.SendMessage(userID, models.MessageTypePayment, title, content, metadata)
	return err
}

func (s *BotMessageService) SendPaymentFailedMessage(userID, reason string) error {
	title := "Pembayaran Gagal ⚠️"
	content := fmt.Sprintf("Maaf, pembayaran Anda tidak dapat diproses.\n\n"+
		"Alasan: %s\n\n"+
		"Silakan coba lagi atau hubungi customer support jika masalah berlanjut.", reason)

	_, err := s.SendMessage(userID, models.MessageTypeAlert, title, content, nil)
	return err
}
