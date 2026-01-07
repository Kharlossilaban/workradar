package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/joho/godotenv"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// Holiday model untuk AutoMigrate
type Holiday struct {
	ID          string    `gorm:"type:varchar(36);primaryKey"`
	UserID      *string   `gorm:"type:varchar(36)"`
	Name        string    `gorm:"type:varchar(255);not null"`
	Date        time.Time `gorm:"type:date;not null"`
	IsNational  bool      `gorm:"default:false"`
	Description *string   `gorm:"type:text"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

func main() {
	godotenv.Load(".env.production")

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_NAME"),
	)

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect:", err)
	}

	// AutoMigrate: Create table if not exists
	log.Println("🔄 Creating holidays table if not exists...")
	if err := db.AutoMigrate(&Holiday{}); err != nil {
		log.Fatal("Failed to create table:", err)
	}
	log.Println("✅ Table ready!")

	holidays := []map[string]interface{}{
		{"name": "Tahun Baru 2026", "date": "2026-01-01", "description": "Tahun Baru Masehi", "is_national": true},
		{"name": "Isra Miraj", "date": "2026-02-17", "description": "Isra Miraj Nabi Muhammad SAW", "is_national": true},
		{"name": "Hari Raya Nyepi", "date": "2026-03-19", "description": "Tahun Baru Saka", "is_national": true},
		{"name": "Wafat Isa Almasih", "date": "2026-04-03", "description": "Jumat Agung", "is_national": true},
		{"name": "Hari Buruh", "date": "2026-05-01", "description": "Hari Buruh Internasional", "is_national": true},
		{"name": "Kenaikan Isa Almasih", "date": "2026-05-14", "description": "Kenaikan Isa Almasih", "is_national": true},
		{"name": "Hari Raya Idul Fitri", "date": "2026-05-17", "description": "Hari Raya Idul Fitri 1447 H (Hari 1)", "is_national": true},
		{"name": "Hari Raya Idul Fitri", "date": "2026-05-18", "description": "Hari Raya Idul Fitri 1447 H (Hari 2)", "is_national": true},
		{"name": "Hari Lahir Pancasila", "date": "2026-06-01", "description": "Hari Lahir Pancasila", "is_national": true},
		{"name": "Hari Raya Idul Adha", "date": "2026-07-24", "description": "Hari Raya Idul Adha 1447 H", "is_national": true},
		{"name": "Tahun Baru Islam", "date": "2026-08-14", "description": "Tahun Baru Islam 1448 H", "is_national": true},
		{"name": "Hari Kemerdekaan RI", "date": "2026-08-17", "description": "Hari Kemerdekaan Republik Indonesia", "is_national": true},
		{"name": "Maulid Nabi Muhammad", "date": "2026-10-23", "description": "Maulid Nabi Muhammad SAW", "is_national": true},
		{"name": "Hari Natal", "date": "2026-12-25", "description": "Hari Natal", "is_national": true},
		{"name": "Tahun Baru 2027", "date": "2027-01-01", "description": "Tahun Baru Masehi", "is_national": true},
	}

	for _, h := range holidays {
		result := db.Exec(
			"INSERT INTO holidays (id, name, date, description, is_national, created_at, updated_at) VALUES (UUID(), ?, ?, ?, ?, NOW(), NOW()) ON DUPLICATE KEY UPDATE name=name",
			h["name"], h["date"], h["description"], h["is_national"],
		)
		if result.Error != nil {
			log.Printf("Error inserting %s: %v", h["name"], result.Error)
		}
	}

	var count int64
	db.Raw("SELECT COUNT(*) FROM holidays").Scan(&count)
	fmt.Printf(" Seeded %d holidays successfully!\n", count)
}
