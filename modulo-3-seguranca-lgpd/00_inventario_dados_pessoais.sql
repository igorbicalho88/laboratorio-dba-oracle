-- =====================================================================
-- Módulo 3 - Segurança e LGPD | Script 00: inventário de dados pessoais
-- Rodar como SYSDBA, dentro da pasta modulo-3-seguranca-lgpd:
--   sqlplus / as sysdba @00_inventario_dados_pessoais.sql
-- Primeiro passo da LGPD: saber ONDE estão os dados pessoais. A classificação
-- fica no próprio dicionário do banco, com as ANNOTATIONS do Oracle 23ai/26ai.
-- =====================================================================
SET LINESIZE 220 PAGESIZE 100 TRIMSPOOL ON ECHO ON
SPOOL logs/00_inventario_dados_pessoais.log
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Recursos de segurança disponíveis nesta edição
COLUMN parameter FORMAT A45
SELECT parameter, value FROM v$option
 WHERE parameter IN ('Data Redaction', 'Fine-grained access control', 'Unified Auditing',
                     'Transparent Data Encryption', 'Oracle Label Security', 'Real Application Security')
 ORDER BY 1;

-- Classificação de cada coluna com dado pessoal (art. 5º da LGPD)
ALTER TABLE lab.clientes MODIFY (
  nome  ANNOTATIONS (ADD dado_pessoal 'identificacao', finalidade 'atendimento e entrega', base_legal 'execucao de contrato'),
  cpf   ANNOTATIONS (ADD dado_pessoal 'identificador unico', finalidade 'emissao de nota fiscal', base_legal 'obrigacao legal', mascarar 'sim'),
  email ANNOTATIONS (ADD dado_pessoal 'contato', finalidade 'avisos do pedido', base_legal 'execucao de contrato', mascarar 'sim'),
  uf    ANNOTATIONS (ADD dado_pessoal 'localizacao (agregada)', finalidade 'logistica e analise', base_legal 'legitimo interesse')
);
ALTER TABLE lab.clientes ANNOTATIONS (ADD contem_dados_pessoais 'sim', titular 'cliente', retencao '5 anos apos o ultimo pedido');

-- Inventário consultável por qualquer ferramenta (relatório do encarregado/DPO)
COLUMN object_name      FORMAT A12
COLUMN column_name      FORMAT A8
COLUMN annotation_name  FORMAT A22
COLUMN annotation_value FORMAT A30
SELECT object_name, column_name, annotation_name, annotation_value
  FROM dba_annotations_usage
 WHERE object_name = 'CLIENTES'
 ORDER BY column_name NULLS FIRST, annotation_name;

-- Volume de titulares
SELECT COUNT(*) AS titulares, COUNT(DISTINCT uf) AS ufs FROM lab.clientes;

SPOOL OFF
EXIT
