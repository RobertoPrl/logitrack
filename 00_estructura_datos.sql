----------------------ESTRUCTURA DE DATOS---------------------------------------

CREATE SCHEMA IF NOT EXISTS logistica;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS staging;

DROP TABLE IF EXISTS audit.cambios_facturas CASCADE;
DROP TABLE IF EXISTS staging.envios_import CASCADE;
DROP TABLE IF EXISTS logistica.facturas CASCADE;
DROP TABLE IF EXISTS logistica.envios CASCADE;
DROP TABLE IF EXISTS logistica.repartidores CASCADE;
DROP TABLE IF EXISTS logistica.clientes CASCADE;
CREATE TABLE logistica.clientes (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nif VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(120) NOT NULL,
    email VARCHAR(160) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    iban VARCHAR(34),
    activo BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE logistica.repartidores (
    id_repartidor BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    matricula VARCHAR(15) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    activo BOOLEAN NOT NULL DEFAULT true
);
CREATE TABLE logistica.envios (
    id_envio BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente BIGINT NOT NULL REFERENCES logistica.clientes(id_cliente),
    id_repartidor BIGINT REFERENCES logistica.repartidores(id_repartidor),
    fecha_envio DATE NOT NULL DEFAULT CURRENT_DATE,
    destino VARCHAR(200) NOT NULL,
    estado VARCHAR(20) NOT NULL
        CHECK (estado IN ('pendiente','preparado','en_reparto','entregado','incidencia')),
    peso_kg NUMERIC(7,2) NOT NULL CHECK (peso_kg > 0)
);

CREATE TABLE logistica.facturas (
    id_factura BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_envio BIGINT NOT NULL REFERENCES logistica.envios(id_envio),
    fecha_factura DATE NOT NULL DEFAULT CURRENT_DATE,
    importe NUMERIC(9,2) NOT NULL CHECK (importe > 0),
    estado VARCHAR(20) NOT NULL
        CHECK (estado IN ('pendiente','emitida','pagada','anulada'))
);
INSERT INTO logistica.clientes
(nif, nombre, email, telefono, iban) VALUES
('B10000001','TecnoNord SL','contacto@tecnonord.test','610111111','ES0011111111111111111111'),
('B20000002','EcoMarket SA','info@ecomarket.test','610222222','ES0022222222222222222222'),
('B30000003','OfiPlus SL','ventas@ofiplus.test','610333333','ES0033333333333333333333');

INSERT INTO logistica.repartidores
(nombre, matricula, telefono) VALUES
('Carlos Riera','1234-LTR','620111111'),
('Lucía Mena','5678-LGX','620222222'),
('David Soler','9012-LGT','620333333');

INSERT INTO logistica.envios
(id_cliente, id_repartidor, destino, estado, peso_kg) VALUES
(1,1,'Barcelona','en_reparto',12.50),
(2,2,'Badalona','preparado',6.20),
(3,3,'Sabadell','entregado',18.00);

INSERT INTO logistica.facturas
(id_envio, importe, estado) VALUES
(1,85.00,'emitida'),
(2,42.50,'pendiente'),
(3,120.00,'pagada');
