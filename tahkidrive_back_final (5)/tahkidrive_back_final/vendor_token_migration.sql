-- Migration : ajouter la table vendor_token si elle n'existe pas
CREATE TABLE IF NOT EXISTS `vendor_token` (
  `id` int NOT NULL AUTO_INCREMENT,
  `vendor_id` varchar(100) NOT NULL,
  `token` varchar(100) NOT NULL,
  `uses_left` int NOT NULL DEFAULT 1,
  `expires_at` datetime NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Exemple : insérer un premier token revendeur pour tester
INSERT INTO `vendor_token` (vendor_id, token, uses_left, expires_at)
VALUES ('VND-001', 'test_vendor_token_dev_2024', 99, '2027-12-31 00:00:00');
