-- ============================================================
--  dv-inventory: extra items voor ESX
--  Importeer dit in je ESX-database (bv. met HeidiSQL of phpMyAdmin).
--  Bestaande items (zoals bread en water van ESX) worden NIET overschreven.
-- ============================================================

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
    ('water', 'Water', 1, 0, 1),
    ('cola', 'Cola', 1, 0, 1),
    ('coffee', 'Koffie', 1, 0, 1),
    ('sandwich', 'Broodje', 1, 0, 1),
    ('burger', 'Burger', 1, 0, 1),
    ('donut', 'Donut', 1, 0, 1),
    ('bandage', 'Verband', 1, 0, 1),
    ('medkit', 'EHBO-kit', 1, 0, 1),
    ('armor', 'Kogelvrij vest', 3, 0, 1),
    ('phone', 'Telefoon', 1, 0, 1),
    ('radio', 'Portofoon', 1, 0, 1),
    ('id_card', 'ID-kaart', 1, 0, 1),
    ('lockpick', 'Lockpick', 1, 0, 1),
    ('repairkit', 'Reparatieset', 2, 0, 1),
    ('cigarette', 'Sigaret', 1, 0, 1),
    ('rope', 'Touw', 1, 0, 1),
    ('ammo_pistol', 'Pistoolmunitie', 1, 0, 1);
