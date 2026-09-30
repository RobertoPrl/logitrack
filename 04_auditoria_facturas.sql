-----------------------------------------------------------------------------------------
-- PROJECT: logitrack_lab
-- MODULE: 04_auditoria_facturas.sql
-- DESCRIPTION: Automated logging engine for billing records using triggers.
-----------------------------------------------------------------------------------------

-- =======================================================================================
-- TAREA 5 · AUDITORIA DE CAMBIOS EN FACTURACIÓN (BILLING CHANGES AUDIT TRAIL)
-- =======================================================================================

-- 1. Create a structured table acting as an immutable audit repository
CREATE TABLE audit.cambios_facturas (
    id_auditoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_factura BIGINT NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_hora TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    operacion VARCHAR(10) NOT NULL,
    importe_anterior NUMERIC(9,2),
    importe_nuevo NUMERIC(9,2),
    estado_anterior VARCHAR(20),
    estado_nuevo VARCHAR(20)
);

-- 2. Define the procedural function to log inserts, updates, and deletes
CREATE OR REPLACE FUNCTION logistica.tg_auditar_facturas()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO audit.cambios_facturas (id_factura, usuario, operacion, importe_nuevo, estado_nuevo)
        VALUES (NEW.id_factura, CURRENT_USER, TG_OP, NEW.importe, NEW.estado);
        RETURN NEW;
        
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.importe IS DISTINCT FROM NEW.importe OR OLD.estado IS DISTINCT FROM NEW.estado) THEN
            INSERT INTO audit.cambios_facturas (
                id_factura, usuario, operacion, 
                importe_anterior, importe_nuevo, 
                estado_anterior, estado_nuevo
            )
            VALUES (
                OLD.id_factura, CURRENT_USER, TG_OP, 
                OLD.importe, NEW.importe, 
                OLD.estado, NEW.estado
            );
        END IF;
        RETURN NEW;
        
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit.cambios_facturas (id_factura, usuario, operacion, importe_anterior, estado_anterior)
        VALUES (OLD.id_factura, CURRENT_USER, TG_OP, OLD.importe, OLD.estado);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER; -- Runs with creator privileges to allow transparent background logging

-- 3. Bind the trigger execution to the invoices table data lifecycle
CREATE TRIGGER trg_facturas_auditoria
AFTER INSERT OR UPDATE OR DELETE ON logistica.facturas
FOR EACH ROW
EXECUTE FUNCTION logistica.tg_auditar_facturas();


-- =======================================================================================
-- VERIFICACION OPERATIVA (CONTROLLED BILLING ALTERATION TESTS)
-- =======================================================================================

-- Switch database session context to the billing operator account
SET ROLE facturacion1;

-- CONTROLLED CHANGE 1: Update the status tracking value on the first invoice record
UPDATE logistica.facturas SET estado = 'pagada' WHERE id_factura = 1;

-- CONTROLLED CHANGE 2: Modify the financial ledger amount due to supplemental fees
UPDATE logistica.facturas SET importe = 55.00 WHERE id_factura = 2;

-- Restore session environment back to system administrator
RESET ROLE;


-- =======================================================================================
-- AUDIT TRAIL LOG EVALUATION
-- =======================================================================================
-- Retrieve and check data modifications captured dynamically by the trigger engine.

SELECT id_factura, usuario, fecha_hora, operacion, importe_anterior, importe_nuevo, estado_anterior, estado_nuevo 
FROM audit.cambios_facturas;