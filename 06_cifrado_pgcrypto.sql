-----------------------------------------------------------------------------------------
-- PROJECT: logitrack_lab
-- MODULE: 06_cifrado_pgcrypto.sql
-- DESCRIPTION: Implementation of symmetric encryption and automatic trigger-based masking.
-----------------------------------------------------------------------------------------

-- =======================================================================================
-- PGCRYPTO CONFIGURATION AND SCHEMA ADAPTATION
-- =======================================================================================

-- Enable the cryptographic extension in the database
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Drop plaintext UNIQUE constraints to allow data obfuscation
ALTER TABLE logistica.clientes DROP CONSTRAINT IF EXISTS clientes_nif_key;
ALTER TABLE logistica.clientes DROP CONSTRAINT IF EXISTS clientes_email_key;

-- 2. Modify nullability temporarily to allow the subsequent obfuscation process
ALTER TABLE logistica.clientes ALTER COLUMN nif DROP NOT NULL;
ALTER TABLE logistica.clientes ALTER COLUMN email DROP NOT NULL;

-- 3. Add new binary columns (BYTEA) to store the encrypted sensitive data
ALTER TABLE logistica.clientes ADD COLUMN nif_cifrado BYTEA;
ALTER TABLE logistica.clientes ADD COLUMN email_cifrado BYTEA;
ALTER TABLE logistica.clientes ADD COLUMN telefono_cifrado BYTEA;
ALTER TABLE logistica.clientes ADD COLUMN iban_cifrado BYTEA;

-- 4. Definition of the function that centralizes the laboratory secret key
CREATE OR REPLACE FUNCTION logistica.fn_obtener_clave_secreta()
RETURNS TEXT AS $$
BEGIN
    RETURN 'ClAvE_SeCrEtA_LoGiTrAcK_2026!';
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- =======================================================================================
-- RETROSPECTIVE DATA MIGRATION (INITIAL CLIENTS)
-- =======================================================================================
-- This block encrypts existing plaintext records and immediately obfuscates them.

DO $$
DECLARE
    v_clave TEXT := logistica.fn_obtener_clave_secreta();
BEGIN
    -- Encrypt current readable data into the new binary columns
    UPDATE logistica.clientes
    SET 
        nif_cifrado = pgp_sym_encrypt(nif, v_clave),
        email_cifrado = pgp_sym_encrypt(email, v_clave),
        telefono_cifrado = CASE WHEN telefono IS NOT NULL THEN pgp_sym_encrypt(telefono, v_clave) ELSE NULL END,
        iban_cifrado = CASE WHEN iban IS NOT NULL THEN pgp_sym_encrypt(iban, v_clave) ELSE NULL END
    WHERE nif_cifrado IS NULL; -- Prevents double encryption if executed multiple times

    -- Overwrite and clean original plaintext columns to secure storage
    UPDATE logistica.clientes
    SET 
        nif = '*** MIGRATED NIF ***',
        email = '*** MIGRATED EMAIL ***',
        telefono = '*** MIGRATED PHONE ***',
        iban = '*** MIGRATED IBAN ***';
END $$;


-- =======================================================================================
-- AUTOMATIC ENCRYPTION FOR NEW RECORDS VIA TRIGGER
-- =======================================================================================

CREATE OR REPLACE FUNCTION logistica.tg_cifrar_datos_cliente()
RETURNS TRIGGER AS $$
DECLARE
    v_clave TEXT := logistica.fn_obtener_clave_secreta();
BEGIN
    -- NIF encryption and hiding
    IF (TG_OP = 'INSERT' AND NEW.nif IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.nif IS DISTINCT FROM OLD.nif) THEN
        NEW.nif_cifrado := pgp_sym_encrypt(NEW.nif, v_clave);
        NEW.nif := '*** PROTECTED NIF ***';
    END IF;

    -- EMAIL encryption and hiding
    IF (TG_OP = 'INSERT' AND NEW.email IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.email IS DISTINCT FROM OLD.email) THEN
        NEW.email_cifrado := pgp_sym_encrypt(NEW.email, v_clave);
        NEW.email := '*** PROTECTED EMAIL ***';
    END IF;

    -- PHONE encryption and hiding
    IF (TG_OP = 'INSERT' AND NEW.telefono IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.telefono IS DISTINCT FROM OLD.telefono) THEN
        NEW.telefono_cifrado := pgp_sym_encrypt(NEW.telefono, v_clave);
        NEW.telefono := '*** PROTECTED PHONE ***';
    END IF;

    -- IBAN encryption and hiding
    IF (TG_OP = 'INSERT' AND NEW.iban IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.iban IS DISTINCT FROM OLD.iban) THEN
        NEW.iban_cifrado := pgp_sym_encrypt(NEW.iban, v_clave);
        NEW.iban := '*** PROTECTED IBAN ***';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger before physical disk insertion
DROP TRIGGER IF EXISTS trg_clientes_cifrado_automatico ON logistica.clientes;
CREATE TRIGGER trg_clientes_cifrado_automatico
BEFORE INSERT OR UPDATE ON logistica.clientes
FOR EACH ROW
EXECUTE FUNCTION logistica.tg_cifrar_datos_cliente();


-- =======================================================================================
-- DECRYPTION VIEW / AUTHORIZED ACCESS
-- =======================================================================================
-- Allows authorized internal modules to query original data without manual decryption overhead.
CREATE OR REPLACE VIEW logistica.v_clientes_seguros AS
SELECT 
    id_cliente,
    nombre,
    pgp_sym_decrypt(nif_cifrado, logistica.fn_obtener_clave_secreta()) AS nif_original,
    pgp_sym_decrypt(email_cifrado, logistica.fn_obtener_clave_secreta()) AS email_original,
    CASE WHEN telefono_cifrado IS NOT NULL THEN pgp_sym_decrypt(telefono_cifrado, logistica.fn_obtener_clave_secreta()) ELSE NULL END AS telefono_original,
    CASE WHEN iban_cifrado IS NOT NULL THEN pgp_sym_decrypt(iban_cifrado, logistica.fn_obtener_clave_secreta()) ELSE NULL END AS iban_original,
    activo
FROM logistica.clientes;


-- =======================================================================================
-- GRANULAR ACCESS CONTROL ON THE DECRYPTION VIEW (SECURITY ACCESS MATRIX)
-- =======================================================================================

-- 1. Revoke any inherited or public access from the decryption view
REVOKE ALL ON logistica.v_clientes_seguros FROM PUBLIC;

-- 2. Grant read privileges (SELECT) only to authorized business roles
GRANT SELECT ON logistica.v_clientes_seguros TO rol_facturacion_logitrack;
GRANT SELECT ON logistica.v_clientes_seguros TO rol_auditoria_logitrack;

-- NOTE: 'rol_almacen_logitrack' and 'rol_expediciones_logitrack' do not receive GRANTs,
-- therefore the PostgreSQL engine will block any query attempts by default.


-- =======================================================================================
-- PRIVILEGE VALIDATION TESTS
-- =======================================================================================

-- TEST 1: Verify the migration status on baseline data (e.g., TecnoNord SL)
SELECT id_cliente, nombre, nif, email, iban_cifrado FROM logistica.clientes WHERE id_cliente = 1;
SELECT id_cliente, nombre, nif_original, email_original, iban_original FROM logistica.v_clientes_seguros WHERE id_cliente = 1;

-- TEST 2: Test trigger execution with a new plaintext insert statement
INSERT INTO logistica.clientes (nif, nombre, email, telefono, iban) 
VALUES ('B50000005', 'Cifrados Avanzados SL', 'contacto@cifrados.test', '699887766', 'ES5544443333222211110000');

-- TEST 3: Check isolation for the new record on both the base table and decrypted view
SELECT id_cliente, nombre, nif, email, telefono, iban FROM logistica.clientes WHERE id_cliente = 4;
SELECT id_cliente, nombre, nif_original, email_original, iban_original FROM logistica.v_clientes_seguros WHERE id_cliente = 4;

-- TEST 4: The billing role MUST BE ALLOWED to view decrypted information
SET ROLE facturacion1;
SELECT id_cliente, nombre, nif_original, iban_original FROM logistica.v_clientes_seguros WHERE id_cliente = 4;
RESET ROLE;

-- TEST 5: The warehouse role MUST BE REJECTED by the system (Throws permission denied error)
SET ROLE almacen1;
-- The following line will fail intentionally, proving policy effectiveness:
SELECT id_cliente, nombre, nif_original FROM logistica.v_clientes_seguros;
RESET ROLE;
