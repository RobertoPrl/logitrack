-----------------------------------------------------------------------------------------
-- PROJECT: logitrack_lab
-- MODULE: 02_roles_permisos_pruebas.sql
-- DESCRIPTION: Creation of group roles, operational logins, Detailed access control, and validation.
-----------------------------------------------------------------------------------------

-- =======================================================================================
-- TAREA 2 · CREAR ROLES Y ASIGNACION (ROLE CREATION & ALLOCATION)
-- =======================================================================================

-- 1. Create group roles acting as permission containers (NOLOGIN)
CREATE ROLE rol_almacen_logitrack NOLOGIN;
CREATE ROLE rol_expediciones_logitrack NOLOGIN;
CREATE ROLE rol_facturacion_logitrack NOLOGIN;
CREATE ROLE rol_supervision_logitrack NOLOGIN;
CREATE ROLE rol_auditoria_logitrack NOLOGIN;

-- 2. Create end-users with explicit operational limits (LOGIN)
CREATE ROLE almacen1 WITH LOGIN PASSWORD 'Almacen_Pass_2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE expediciones1 WITH LOGIN PASSWORD 'Expediciones_Pass_2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE facturacion1 WITH LOGIN PASSWORD 'Facturacion_Pass_2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE supervisor1 WITH LOGIN PASSWORD 'Supervisor_Pass_2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE auditor1 WITH LOGIN PASSWORD 'Auditor_Pass_2026!' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- 3. Assign end-users to their corresponding group infrastructure roles
GRANT rol_almacen_logitrack TO almacen1;
GRANT rol_expediciones_logitrack TO expediciones1;
GRANT rol_facturacion_logitrack TO facturacion1;
GRANT rol_supervision_logitrack TO supervisor1;
GRANT rol_auditoria_logitrack TO auditor1;


-- =======================================================================================
-- COMPROBACIÓN (ROLE PRIVILEGE VERIFICATION METADATA)
-- =======================================================================================
-- Query system catalogs to ensure structural integrity and correct role memberships.

SELECT 
    r.rolname AS nombre_rol,
    r.rolcanlogin AS puede_iniciar_sesion,
    r.rolsuper AS es_superusuario,
    r.rolcreatedb AS puede_crear_db,
    r.rolcreaterole AS puede_crear_roles,
    ARRAY_TO_STRING(ARRAY(
        SELECT g.rolname 
        FROM pg_auth_members m 
        JOIN pg_roles g ON m.roleid = g.oid 
        WHERE m.member = r.oid
    ), ', ') AS grupos_asignados
FROM 
    pg_roles r
WHERE 
    r.rolname IN (
        'rol_almacen_logitrack', 'rol_expediciones_logitrack', 'rol_facturacion_logitrack', 'rol_supervision_logitrack', 'rol_auditoria_logitrack',
        'almacen1', 'expediciones1', 'facturacion1', 'supervisor1', 'auditor1'
    )
ORDER BY 
    r.rolcanlogin DESC, r.rolname ASC;


-- =======================================================================================
-- TAREA 3 · APLICAR PERMISOS (APPLICATION OF SCHEMATIC & OBJECT PRIVILEGES)
-- =======================================================================================

-- Revoke default public inheritance properties over public schemas
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- Establish database entry connections for operational definitions
GRANT CONNECT ON DATABASE logitrack_lab TO rol_almacen_logitrack;
GRANT CONNECT ON DATABASE logitrack_lab TO rol_expediciones_logitrack;
GRANT CONNECT ON DATABASE logitrack_lab TO rol_facturacion_logitrack;
GRANT CONNECT ON DATABASE logitrack_lab TO rol_supervision_logitrack;
GRANT CONNECT ON DATABASE logitrack_lab TO rol_auditoria_logitrack;

-- ---------------------------------------------------------------------------------------
-- ROL ALMACEN (WAREHOUSE OPERATIONS SCHEMA MAPPING)
-- ---------------------------------------------------------------------------------------
GRANT USAGE ON SCHEMA logistica TO rol_almacen_logitrack;

-- Consulta general de envíos
GRANT SELECT ON logistica.envios TO rol_almacen_logitrack;
-- Modificación exclusiva del estado logístico
GRANT UPDATE (estado) ON logistica.envios TO rol_almacen_logitrack;

-- ---------------------------------------------------------------------------------------
-- ROL EXPEDICIONES (DISPATCH OPERATIONS PRIVILEGES)
-- ---------------------------------------------------------------------------------------
GRANT USAGE ON SCHEMA logistica TO rol_expediciones_logitrack;

-- Consulta de clientes y envíos
GRANT SELECT ON logistica.clientes TO rol_expediciones_logitrack;
GRANT SELECT ON logistica.envios TO rol_expediciones_logitrack;
-- Permiso para asignar un repartidor (y opcionalmente pasar a 'en_reparto')
GRANT UPDATE (id_repartidor, estado) ON logistica.envios TO rol_expediciones_logitrack;

-- ROL EXPEDICIONES (DUPLICATED BLOCK FOR ARCHITECTURE CONSISTENCY VERIFICATION)
GRANT USAGE ON SCHEMA logistica TO rol_expediciones_logitrack;

-- Consulta de clientes y envíos
GRANT SELECT ON logistica.clientes TO rol_expediciones_logitrack;
GRANT SELECT ON logistica.envios TO rol_expediciones_logitrack;
-- Permiso para asignar un repartidor
GRANT UPDATE (id_repartidor, estado) ON logistica.envios TO rol_expediciones_logitrack;

-- ---------------------------------------------------------------------------------------
-- ROL FACTURACION (FINANCIAL AND BILLING OBJECT ACCESS)
-- ---------------------------------------------------------------------------------------
GRANT USAGE ON SCHEMA logistica TO rol_facturacion_logitrack;

-- Consulta de envíos y gestión total de facturas 
GRANT SELECT ON logistica.envios TO rol_facturacion_logitrack;
GRANT SELECT, INSERT, UPDATE, DELETE ON logistica.facturas TO rol_facturacion_logitrack;
GRANT USAGE, SELECT ON SEQUENCE logistica.facturas_id_factura_seq TO rol_facturacion_logitrack;

-- ---------------------------------------------------------------------------------------
-- ROL SUPERVISOR (REPORTING DASHBOARD FRAMEWORK IMPLEMENTATION)
-- ---------------------------------------------------------------------------------------
GRANT USAGE ON SCHEMA logistica TO rol_supervision_logitrack;

CREATE OR REPLACE VIEW logistica.v_supervision_cuadro_mando AS 
SELECT e.id_envio, c.nombre AS cliente, e.destino, e.estado AS estado_envio, f.importe, f.estado AS estado_factura
FROM logistica.envios e
JOIN logistica.clientes c ON e.id_cliente = c.id_cliente
LEFT JOIN logistica.facturas f ON e.id_envio = f.id_envio;

-- Supervisión solo trabaja a través de la vista
GRANT SELECT ON logistica.v_supervision_cuadro_mando TO rol_supervision_logitrack;

-- ---------------------------------------------------------------------------------------
-- ROL AUDIT / AUDITORIA (FORENSIC READ-ONLY AUDITING PRIVILEGES)
-- ---------------------------------------------------------------------------------------
-- ROL AUDIT
GRANT USAGE ON SCHEMA logistica, audit TO rol_auditoria_logitrack;

-- Consulta de información y evidencias
GRANT SELECT ON ALL TABLES IN SCHEMA logistica TO rol_auditoria_logitrack;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO rol_auditoria_logitrack;

-- ROL AUDITORIA
GRANT USAGE ON SCHEMA logistica, audit TO rol_auditoria_logitrack;

-- Consulta de información y evidencias, cero modificaciones
GRANT SELECT ON ALL TABLES IN SCHEMA logistica TO rol_auditoria_logitrack;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO rol_auditoria_logitrack;


-- =======================================================================================
-- PRUEBAS (INTEGRATION VALIDATION THROUGH SESSION SWITCHING)
-- =======================================================================================

-- ---------------------------------------------------------------------------------------
-- almacen1 TESTS
-- ---------------------------------------------------------------------------------------
SET ROLE almacen1;
-- OPERACIÓN PERMITIDA: Actualizar el estado logístico de un envío
UPDATE logistica.envios SET estado = 'preparado' WHERE id_envio = 1;
-- OPERACIÓN DENEGADA: Intentar cambiar el destino del paquete (Provoca error de permisos)
-- UPDATE logistica.envios SET destino = 'Madrid' WHERE id_envio = 1;
RESET ROLE;

-- ---------------------------------------------------------------------------------------
-- expediciones1 TESTS
-- ---------------------------------------------------------------------------------------
SET ROLE expediciones1;
-- OPERACIÓN PERMITIDA: Consultar la tabla de clientes
SELECT * FROM logistica.clientes LIMIT 1;
-- OPERACIÓN PERMITIDA: Asignar un repartidor a un envío
UPDATE logistica.envios SET id_repartidor = 2 WHERE id_envio = 1;
-- OPERACIÓN DENEGADA: Intentar modificar los datos de un cliente (Provoca error de permisos)
-- UPDATE logistica.clientes SET nombre = 'Hacker SL' WHERE id_cliente = 1;
RESET ROLE;

-- ---------------------------------------------------------------------------------------
-- facturacion1 TESTS
-- ---------------------------------------------------------------------------------------
SET ROLE facturacion1;
-- OPERACIÓN PERMITIDA: Consultar la tabla de envíos
SELECT * FROM logistica.envios LIMIT 1;
-- OPERACIÓN PERMITIDA: Insertar una nueva factura en el sistema
INSERT INTO logistica.facturas (id_envio, importe, estado) VALUES (3, 150.00, 'emitida');
-- OPERACIÓN DENEGADA: Intentar modificar datos de un repartidor (Provoca error de permisos)
-- UPDATE logistica.repartidores SET telefono = '600000000' WHERE id_repartidor = 1;
RESET ROLE;

-- ---------------------------------------------------------------------------------------
-- supervisor1 TESTS
-- ---------------------------------------------------------------------------------------
SET ROLE supervisor1;
-- OPERACIÓN PERMITIDA: Consultar el cuadro de mando unificado desde la vista autorizada
SELECT * FROM logistica.v_supervision_cuadro_mando;
-- OPERACIÓN DENEGADA: Intentar consultar directamente una tabla base (Provoca error de permisos)
-- SELECT * FROM logistica.clientes;
RESET ROLE;


