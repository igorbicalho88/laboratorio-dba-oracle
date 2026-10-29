-- =====================================================================
-- Módulo 1 - Tuning | Script 01: tabelas e carga de dados (~15 milhões de linhas)
-- Rodar como LAB:  sqlplus lab/<senha>@//localhost:1521/FREEPDB1 @01_carga_dados.sql
-- Leva alguns minutos.
-- =====================================================================
WHENEVER SQLERROR EXIT FAILURE
SET TIMING ON
SET ECHO ON

-- Modelo de um e-commerce. Propositalmente SEM índices além das chaves
-- primárias e do CPF: é o "antes" do tuning.
CREATE TABLE clientes (
  cliente_id     NUMBER        CONSTRAINT pk_clientes PRIMARY KEY,
  nome           VARCHAR2(60)  NOT NULL,
  cpf            VARCHAR2(11)  NOT NULL CONSTRAINT uk_clientes_cpf UNIQUE,
  email          VARCHAR2(80),
  uf             CHAR(2),
  data_cadastro  DATE
);

CREATE TABLE produtos (
  produto_id  NUMBER        CONSTRAINT pk_produtos PRIMARY KEY,
  nome        VARCHAR2(60)  NOT NULL,
  categoria   VARCHAR2(30)  NOT NULL,
  preco       NUMBER(10,2)  NOT NULL
);

CREATE TABLE pedidos (
  pedido_id    NUMBER        CONSTRAINT pk_pedidos PRIMARY KEY,
  cliente_id   NUMBER        NOT NULL CONSTRAINT fk_pedidos_clientes REFERENCES clientes,
  data_pedido  DATE          NOT NULL,
  status       VARCHAR2(10)  NOT NULL,
  canal        VARCHAR2(10)  NOT NULL,
  valor_total  NUMBER(12,2)  NOT NULL
);

CREATE TABLE itens_pedido (
  item_id         NUMBER        CONSTRAINT pk_itens PRIMARY KEY,
  pedido_id       NUMBER        NOT NULL CONSTRAINT fk_itens_pedidos REFERENCES pedidos,
  produto_id      NUMBER        NOT NULL CONSTRAINT fk_itens_produtos REFERENCES produtos,
  quantidade      NUMBER(3)     NOT NULL,
  preco_unitario  NUMBER(10,2)  NOT NULL
);

-- 200 mil clientes (CPF fictício, só dígitos)
INSERT /*+ APPEND */ INTO clientes
WITH g AS (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 200000)
SELECT n,
       'Cliente ' || n,
       TO_CHAR(10000000000 + n * 37),
       'cliente' || n || '@exemplo.com',
       CASE MOD(ORA_HASH(n), 10)
         WHEN 0 THEN 'MG' WHEN 1 THEN 'RJ' WHEN 2 THEN 'RS' WHEN 3 THEN 'PR' WHEN 4 THEN 'BA'
         WHEN 5 THEN 'SC' WHEN 6 THEN 'PE' WHEN 7 THEN 'GO' ELSE 'SP' END,
       DATE '2020-01-01' + MOD(ORA_HASH(n * 3), 1800)
  FROM g;
COMMIT;

-- 5 mil produtos em 20 categorias
INSERT /*+ APPEND */ INTO produtos
WITH g AS (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 5000)
SELECT n,
       'Produto ' || n,
       'Categoria ' || LPAD(MOD(n, 20) + 1, 2, '0'),
       ROUND(10 + MOD(ORA_HASH(n), 99000) / 100, 2)
  FROM g;
COMMIT;

-- 5 milhões de pedidos entre jan/2023 e out/2025
INSERT /*+ APPEND */ INTO pedidos
WITH a AS (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 5000),
     b AS (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 1000),
     g AS (SELECT (a.n - 1) * 1000 + b.n AS n FROM a CROSS JOIN b)
SELECT n,
       MOD(ORA_HASH(n), 200000) + 1,
       DATE '2023-01-01' + MOD(ORA_HASH(n * 7), 1035) + MOD(ORA_HASH(n * 11), 86400) / 86400,
       CASE WHEN MOD(ORA_HASH(n * 13), 100) < 5  THEN 'CANCELADO'
            WHEN MOD(ORA_HASH(n * 13), 100) < 15 THEN 'PENDENTE'
            ELSE 'ENTREGUE' END,
       CASE MOD(ORA_HASH(n * 17), 3) WHEN 0 THEN 'SITE' WHEN 1 THEN 'APP' ELSE 'LOJA' END,
       ROUND(20 + MOD(ORA_HASH(n * 19), 98000) / 100, 2)
  FROM g;
COMMIT;

-- 10 milhões de itens
INSERT /*+ APPEND */ INTO itens_pedido
WITH a AS (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 10000),
     b AS (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 1000),
     g AS (SELECT (a.n - 1) * 1000 + b.n AS n FROM a CROSS JOIN b)
SELECT n,
       MOD(ORA_HASH(n * 23), 5000000) + 1,
       MOD(ORA_HASH(n * 29), 5000) + 1,
       MOD(ORA_HASH(n * 31), 5) + 1,
       ROUND(10 + MOD(ORA_HASH(n * 37), 99000) / 100, 2)
  FROM g;
COMMIT;

-- Estatísticas para o otimizador
EXEC DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER, cascade => TRUE)

SET ECHO OFF
COLUMN segment_name FORMAT A25
SELECT segment_name, segment_type, ROUND(SUM(bytes)/1024/1024) AS mb
  FROM user_segments GROUP BY segment_name, segment_type ORDER BY mb DESC;
SELECT 'clientes' AS tabela, COUNT(*) AS linhas FROM clientes UNION ALL
SELECT 'produtos', COUNT(*) FROM produtos UNION ALL
SELECT 'pedidos', COUNT(*) FROM pedidos UNION ALL
SELECT 'itens_pedido', COUNT(*) FROM itens_pedido;
EXIT
