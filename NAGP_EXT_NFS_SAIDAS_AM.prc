CREATE OR REPLACE PROCEDURE NAGP_EXT_NFS_SAIDAS_AM (vsDtaInicial DATE, vsDtaFinal DATE, psTipoAgrup VARCHAR2) IS

    v_file UTL_FILE.file_type;
    v_line VARCHAR2(32767);
    v_Targetcharset varchar2(40 BYTE);
    v_Dbcharset varchar2(40 BYTE);
    v_Cabecalho VARCHAR2(32767);
    v_LineConteudo VARCHAR2(32767);
    v_Periodo VARCHAR2(100);
    v_buffer CLOB;
    v_chunk_size CONSTANT PLS_INTEGER := 32000;
    -- v_emparq VARCHAR2(100);
    vchave VARCHAR2(3000);
    v_varcsv VARCHAR2(400);
    v_dtini DATE;
    v_dtfim DATE;

BEGIN
  
    
    FOR t IN (SELECT DISTINCT CASE WHEN psTipoAgrup = 'F' THEN 'Full' 
                                   WHEN psTipoAgrup IN ('D','I') THEN REPLACE(TO_CHAR(X.DTA, 'DD/MM/YYYY'), '/','_') 
                                   WHEN psTipoAgrup = 'S' THEN 'S'||SEMANA||'_'||MES||'_'||ANO
                                   WHEN psTipoAgrup = 'M' THEN MES||'_'||ANO
                                   WHEN psTipoAgrup = 'A' THEN ANO
                               END agrup_arq, MIN(DTA) dtamin, MAX(DTA) dtamax
                FROM DIM_TEMPO X
               WHERE X.DTA BETWEEN vsDtaInicial AND vsDtaFinal
               GROUP BY CASE WHEN psTipoAgrup = 'F' THEN 'Full' 
                                   WHEN psTipoAgrup IN ('D','I') THEN REPLACE(TO_CHAR(X.DTA, 'DD/MM/YYYY'), '/','_') 
                                   WHEN psTipoAgrup = 'S' THEN 'S'||SEMANA||'_'||MES||'_'||ANO
                                   WHEN psTipoAgrup = 'M' THEN MES||'_'||ANO
                                   WHEN psTipoAgrup = 'A' THEN ANO
                               END 
               ORDER BY 2)
               
    LOOP
    
     -- Recebe as variaveis de Data e Nome do Agrupamento pra inserir no tit do arquivo
      v_dtini  := t.dtamin;
      v_dtfim  := t.dtamax;
      v_varcsv := t.agrup_arq;
    
   -- V_Periodo := REPLACE(t.ANOMESDESCRICAO, '/','_');
    -- Abre o arquivo para escrita
    v_file := UTL_FILE.fopen('EXT_AM', 'Ext_NF_Saidas_'||v_varcsv||'.csv', 'w', 32767);

    -- Pega o nome das colunas para inserir no cabecalho pq tenho preguica
    SELECT LISTAGG(COLUMN_NAME,';') WITHIN GROUP (ORDER BY COLUMN_ID)
      INTO v_Cabecalho
      FROM ALL_TAB_COLUMNS A
     WHERE A.table_name = 'NAGV_DADOS_NF_SAIDA_AM'
       AND COLUMN_NAME NOT IN ('ORIGEM','00','NROEMPRESA');
 
    UTL_FILE.put_line(v_file, v_Cabecalho);

    -- Executa a query e escreve os resultados

      FOR bs IN (SELECT *                                      
                    FROM NAGV_DADOS_NF_SAIDA_AM X
                   WHERE 1=1
                     AND X.DTAMOVIMENTO BETWEEN t.dtamin AND t.dtamax
                     AND X.NROEMPRESA IN (8,14))

      LOOP

        v_line :=         bs.DTAMOVIMENTO
                   ||';'||bs.CNPJ_EMPRESA
                   ||';'||bs.RAIZ_CNPJ
                   ||';'||bs.CANAL_VENDA
                   ||';'||bs.NCM
                   ||';'||bs.SKU
                   ||';'||bs.CNPJ_TOMADOR
                   ||';'||bs.UF_ORIGEM
                   ||';'||bs.UF_DESTINO
                   ||';'||bs.TIPO_OPERACAO
                   ||';'||bs.TIPO_MOVIMENTACAO
                   ||';'||bs.DESCRICAO_PRODUTO_SERVICO
                   ||';'||bs.CFOP
                   ||';'||bs.CST
                   ||';'||bs.QTD
                   ||';'||bs.UNIDADE
                   ||';'||bs.FATOR_CONVERSAO
                   ||';'||bs.VALOR_OPERACAO
                   ||';'||bs.DESCONTO_INCONDICIONAL
                   ||';'||bs.DESCONTO_CONDICIONAL
                   ||';'||bs.IPI
                   ||';'||bs.PIS_COFINS
                   ||';'||bs.ICMS
                   ||';'||bs.ICMS_ST
                   ||';'||bs.ISS
                   ||';'||bs.INCENTIVO_FISCAL_PIS_COFINS
                   ||';'||bs.INCENTIVO_FISCAL_ICMS
                   ||';'||bs.COGS_TOTAL
                   ||';'||bs.COGS_CUSTOS_SERVICOS_PRESTADOS
                   ||';'||bs.COGS_FOPAG
                   ||';'||bs.SGA_TOTAL
                   ||';'||bs.SGA_FOPAG
                   ||';'||bs.SGA_DESPESAS_OPERACIONAIS
                   ||';'||bs.NFECHAVEACESSO;
                  
        v_buffer := v_buffer || v_line || CHR(13); -- Adiciona nova linha ao buffer        
        
        IF LENGTH(v_buffer) > v_chunk_size THEN
            UTL_FILE.put_line(v_file, v_buffer); -- Escreve o buffer no arquivo
            v_buffer := ''; -- Limpa o buffer
            
        END IF;
                
    END LOOP;
    
    -- Grava o restante do buffer no final (burro esqueceu)
    IF v_buffer IS NOT NULL THEN
      
        UTL_FILE.put_line(v_file, v_buffer);
        v_buffer := '';
    END IF;
    
    -- Fecha o arquivo
    UTL_FILE.fclose(v_file);

COMMIT;
     END LOOP;

    EXCEPTION

    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE(v_line|| ' - '|| SQLERRM);
      DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('Error Message: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Stack: ' || DBMS_UTILITY.FORMAT_ERROR_STACK);
        DBMS_OUTPUT.PUT_LINE('Error Backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        DBMS_OUTPUT.PUT_LINE('Call Stack: ' || DBMS_UTILITY.FORMAT_CALL_STACK);
        
        IF UTL_FILE.is_open(v_file) THEN
            UTL_FILE.fclose(v_file);
        END IF;
        RAISE;
        
        

END;
