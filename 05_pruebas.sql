-----------------------------------------------------------------------------------------
-- PROJECT: logitrack_lab
-- MODULE: 05_pruebas.sql
-- DESCRIPTION: Multi-role authentication and verification test script.
-----------------------------------------------------------------------------------------

-- =======================================================================================
-- TAREA 6 · PRUEBAS DE USUARIOS (END-USER SECURITY & ACCESS VALIDATION)
-- =======================================================================================

-- ---------------------------------------------------------------------------------------
-- WAREHOUSE ACCOUNT VALIDATION (almacen1)
-- ---------------------------------------------------------------------------------------
-- Switch database session context to the warehouse user identity
SET ROLE almacen1;

-- ALLOWED ACTION: Update the logistical tracking status of an existing shipment record
UPDATE logistica.envios SET estado = 'preparado' WHERE id_envio = 1;

-- DENIED ACTION: Attempt to scan billing ledger tables (Triggers a permission error)
-- The following statement is hard-blocked and has been commented out to prevent script failure:
-- SELECT * FROM logistica.facturas;

-- Revert the session context back to database administrator
RESET ROLE;


-- ---------------------------------------------------------------------------------------
-- EXPEDITIONS ACCOUNT VALIDATION (expediciones1)
-- ---------------------------------------------------------------------------------------
-- Switch database session context to the expeditions user identity
SET ROLE expediciones1;

-- ALLOWED ACTION: Assign a delivery driver tracking value to a specific package
UPDATE logistica.envios SET id_repartidor = 2 WHERE id_envio = 1;

-- DENIED ACTION: Attempt to overwrite internal invoice financial balances (Triggers a permission error)
-- UPDATE logistica.facturas SET importe = 500.00 WHERE id_factura = 1;

-- Revert the session context back to database administrator
RESET ROLE;


-- ---------------------------------------------------------------------------------------
-- BILLING ACCOUNT VALIDATION (facturacion1)
-- ---------------------------------------------------------------------------------------
-- Switch database session context to the billing user identity
SET ROLE facturacion1;

-- ALLOWED ACTION: Modify and update the current status parameter of a customer invoice
UPDATE logistica.facturas SET estado = 'pagada' WHERE id_factura = 1;

-- DENIED ACTION: Attempt to modify delivery carrier personal registry parameters (Triggers a permission error)
-- UPDATE logistica.repartidores SET telefono = '600000000' WHERE id_repartidor = 1;

-- Revert the session context back to database administrator
RESET ROLE;


-- ---------------------------------------------------------------------------------------
-- SUPERVISION ACCOUNT VALIDATION (supervisor1)
-- ---------------------------------------------------------------------------------------
-- Switch database session context to the supervisor user identity
SET ROLE supervisor1;

-- ALLOWED ACTION: Query the authorized decoupled status view for tracking reports
SELECT * FROM logistica.v_estado_general_envios;

-- DENIED ACTION: Attempt to query raw ledger metrics directly from the base table (Triggers a permission error)
-- SELECT * FROM logistica.facturas;

-- Revert the session context back to database administrator
RESET ROLE;


-- ---------------------------------------------------------------------------------------
-- AUDITING ACCOUNT VALIDATION (auditor1)
-- ---------------------------------------------------------------------------------------
-- Switch database session context to the auditor user identity
SET ROLE auditor1;

-- ALLOWED ACTION: Review historical security change tracking data within the audit logs
SELECT * FROM audit.cambios_facturas;

-- DENIED ACTION: Attempt to alter core operational billing data manually (Triggers a permission error)
-- UPDATE logistica.facturas SET importe = 1.00 WHERE id_factura = 1;

-- Revert the session context back to database administrator
RESET ROLE;
