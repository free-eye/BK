CREATE OR REPLACE PROCEDURE                  PB_SHBAT0550C_030_11 
/*** 履歴 **************************************************************/
/* 2023/09/12_KDP導入_HISYS_C.LIU 仕入管理  新規作成(仕入計上)       */
/***********************************************************************/
(
      CUR OUT SYS_REFCURSOR,
      PKAICD         IN  NUMBER,       --会社コード
      PJGYCD         IN  NUMBER,       --事業部コード
      PJOBDT         IN  NUMBER,       -- ジョブ日付
      PUPPC          IN  VARCHAR2,     --クライアントＰＣ（IPアドレス）
      PUPUSER        IN  VARCHAR2,     --ﾊﾞｯﾁ起動ﾕｰｻﾞ
      PDENNO         IN NUMBER,        --発注番号
      PJYUDT         IN NUMBER,        --受領日 
      PTENCD         IN NUMBER,        --店舗コード
      PJANCD         IN VARCHAR2,      --JANコード 
      PHACZSU        IN NUMBER,        --発注残数
      PKPNSU         IN NUMBER,        --検品数 
      PFINFLG        IN NUMBER,        --完了ブログ
      PSHICD         IN NUMBER,        --仕入先 
      PHACDT         IN NUMBER,        --発注日
      PDENGYO        IN NUMBER,        --伝票行番号
      COMPAREDRESULT IN NUMBER,        --1件前の店舗コード、発注番号、発注日の照合結果：０：一致、１：不一致
      --2023/10/26_KDP導入_HISYS_C.LIU_ADD_START
      ISLAST         IN NUMBER         --1件後の店舗コード、発注番号、発注日の照合結果：０：一致、１：不一致（当日単品実績マスタの更新）
      --2023/10/26_KDP導入_HISYS_C.LIU_ADD_END
)
AS 
/*============================================================================*/
/* 変数宣言                                                     */
/*============================================================================*/
    CPGMID       CONSTANT VARCHAR2(256) := 'SHBAT0550C';    --プログラムＩＤ
    WK_PROC      VARCHAR2(500);
    WK_ERRMSG             VARCHAR2(500);
    WK_STEP               VARCHAR2(500);
    WK_SYSDATE            NUMBER;                           --ワーク項目システム日付
    WK_SYSEXEHMS          NUMBER;                           --ワーク項目システム時間
    WK_SEQ                NUMBER;                           --ワーク項目連番
    WK_FCSTEP             VARCHAR2(500)   := '';            --(関数用)処理名
    WK_FCERRCD            INTEGER         := 0;             --(関数用)エラーコード
    WK_FCERRMG            VARCHAR2(500)   := '';            --(関数用)エラーメッセージ
    
    VHACDT       NUMBER;
    MAX_SIRSEQ   NUMBER;
    INS_SIRSEQ   NUMBER;
    VKAICD       NUMBER;
    VJGYCD       NUMBER;
    VTENCD       NUMBER;
    VSHICD       NUMBER;
    VDENNO       NUMBER;
    VHACZSU      NUMBER;
    VSHRFLG      NUMBER;
    --2024/03/22_AT_課題修正一覧(仕入業務)_00__HISYS_C.LIU_ADD_START
    V_DENHASUKBN NUMBER;	
    V_T_ZEIKBN   NUMBER;	
    V_BZHASUKBN  NUMBER;	
    V_GZHASUKBN  NUMBER;	
    --2024/03/22_AT_課題修正一覧(仕入業務)_00__HISYS_C.LIU_ADD_END
/*============================================================================*/
/* カーソル宣言                                                     */
/*============================================================================*/
    
    CURSOR KBCUR IS
    SELECT
    --2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
        --haczsu,dengyo
        ODRSU - SHISU AS ZANSU,
        JANCD,
        KPNKBN,
        KH.DENNO　AS DENNO
    --2023/10/13_KDP導入_HISYS_C.LIU_MOD_END
    FROM
         KENBTRN KB
                    LEFT  JOIN KENHTRN KH
                    ON KB.DENNO=KH.DENNO
                     AND KB.KAICD = KH.KAICD
                     AND KB.JGYCD = KH.JGYCD
                     AND KB.TENCD = KH.TENCD
                     AND KB.SHICD = KH.SHICD
                     AND KB.DENSYU = KH.DENSYU
    WHERE
            KB.KAICD = PKAICD
        AND KB.JGYCD = PJGYCD
        AND KB.TENCD = PTENCD
        AND KH.HACNO = PDENNO;
--2024/03/22_AT_課題修正一覧(仕入業務)_00__HISYS_C.LIU_MOD_START          
--     CURSOR shcur is select
--        kaicd,
--        jgycd,
--        tencd,
--        shicd,
--        denno
--    from 
--         sirhtrn
--    where
--         kaicd = pkaicd
--        AND jgycd = pjgycd
--        AND tencd = ptencd
--        AND shicd = pshicd
--        AND hacno = pdenno
--        and hacdt = phacdt;
    CURSOR SHCUR IS SELECT	
        KAICD,	
        JGYCD,	
        TENCD,	
        SHICD,	
        DENNO	
    FROM	
        (	
        SELECT	
            KAICD,	
            JGYCD,	
            TENCD,	
            SHICD,	
            DENNO	
        FROM 	
            SIRHTRN	
        WHERE	
            KAICD = PKAICD	
        AND JGYCD = PJGYCD	
        AND TENCD = PTENCD	
        AND SHICD = PSHICD	
        AND HACNO = PDENNO	
        AND HACDT = PHACDT	
        ORDER BY HACNO ,SIRSEQ DESC	
        )	
    WHERE	
        ROWNUM = 1;	
--2024/03/22_AT_課題修正一覧(仕入業務)_00__HISYS_C.LIU_MOD_END 
/*============================================================================*/
/* ファンクション宣言                                                     */
/*============================================================================*/
--仕入見出しトランを登録
    FUNCTION INSSIRHTRN (
        PKAICD          IN NUMBER,
        PJGYCD          IN NUMBER,
        PHACNO          IN NUMBER,
        PTENCD          IN NUMBER,
        PUPPC           IN VARCHAR2,
        PUPUSER         IN VARCHAR2,
        COMPAREDRESULT IN NUMBER,
        PSHICD          IN NUMBER,
        PHACDT          IN NUMBER
    ) RETURN INTEGER IS
    --2024/02/29 ADD STR SYS.koba	
    W_WEEK     WEEKMST.WEEK%TYPE;	
    --2024/02/29 ADD END	
    BEGIN
        SELECT
            NVL(MAX(SIRSEQ),
                0) + 1
        INTO INS_SIRSEQ
        FROM
            SIRHTRN　--仕入見出しトラン
        WHERE
                HACNO = PDENNO  --発注番号の照合
            --2024/02/29 ADD STR SYS.koba	
            AND TENCD = PTENCD	
            --2024/02/29 UPD END	
            AND HACDT = PHACDT; --発注日の照合
        
        --2024/02/29 ADD STR SYS.koba	
        --検収日での営業週取得	
        BEGIN	
            SELECT	
                   NVL(WEEKMST.WEEK    , 0 ) AS WK_WEEK	
              INTO W_WEEK	
              FROM WEEKMST	
             WHERE KAICD   = PKAICD	
               AND JGYCD   = PJGYCD	
               AND WSTADT <= PJYUDT	
               AND WENDDT >= PJYUDT	
            ;	
        EXCEPTION	
            WHEN OTHERS THEN	
                WK_FCERRCD := SQLCODE;	
                WK_FCERRMG := SUBSTR('[週管理マスタ] : ' || WK_FCSTEP || ' : ' || SQLERRM, 1, 500);	
                RETURN WK_FCERRCD;	
        END;	
        --2024/02/29 ADD END	
        
        INSERT INTO SIRHTRN (
            KAICD,
            JGYCD,
            TENCD,
            SHICD,
            DENSYU,
            DENNO,
            PBKBN,
            NOUDT,
            KENDT,
--2023/11/15_KDP導入_HISYS_C.LIU_ADD_START
            DENDT,
--2023/11/15_KDP導入_HISYS_C.LIU_ADD_END
            --2024/02/29 ADD STR SYS.koba	
            WEEK,	
            --2024/02/29 ADD END	
            PAYKBN,
            PAYCNT,
            GKAZEI,
            BKAZEI,
            --2024/02/29 ADD STR SYS.koba	
            KYAKKBN,	
            --2024/02/29 ADD END	
            CENTERCD,
            --2024/02/29 ADD STR SYS.koba	
            DTMAKKBN,	
            GET_FLG,	
            KAI_FLG,	
            --2024/02/29 ADD END	
            MAKDT,
            MAKTM,
            HACNO,
            HAICD,
            HAIPTN,
            ONLKBN,
            DCHACKBN,
            --2024/02/29 ADD STR SYS.koba	
            HACTYPE,	
            --2024/02/29 ADD END	
            UPDKBN,
            SIRSEQ,
            UPDT,
            UPTM,
            PGMID,
            UPPC,
            UPUSER,
            HACDT
        )
            SELECT
                KH.KAICD,
                KH.JGYCD,
                KH.TENCD,
                KH.SHICD,
--2024/01/11_KDP導入_HISYS_C.LIU_MOD_START
                --kh.densyu,
                COMCONST.CDENSYU_SIRETEGAKI,
--2024/01/11_KDP導入_HISYS_C.LIU_MOD_END
                VDENNO,
                KH.PBKB,
                KH.NOUDT,
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
--              kh.kendt,
                PJYUDT,
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
--2023/11/15_KDP導入_HISYS_C.LIU_ADD_START
                PJYUDT,
--2023/11/15_KDP導入_HISYS_C.LIU_ADD_END
                --2024/02/29 ADD STR SYS.koba	
                W_WEEK,	
                --2024/02/29 ADD END	
                KH.PAYKBN,
                KH.PAYCNT,
                KH.GKAZEI,
                KH.BKAZEI,
                --2024/02/29 ADD STR SYS.koba	
                KH.KYAKUFLG,	
                --2024/02/29 ADD END	
                KH.CENTERCD,
                --2024/02/29 ADD STR SYS.koba	
                COMCONST.CDTMAKKBN_HANDY,	
                0,	
                0,	
                --2024/02/29 ADD END	
                WK_SYSDATE,
                WK_SYSEXEHMS,
                PDENNO,
                KH.HAICD,
                KH.HAIPTN,
                KH.ONLKBN,
                KH.DCHACKBN,
                --2024/02/29 ADD STR SYS.koba	
                KH.HACTYPE,	
                --2024/02/29 ADD END	
                0,
                INS_SIRSEQ,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_START
--                wk_sysdate,
--                wk_sysexehms,
                0,
                0,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_END
                CPGMID,
                PUPPC,
                PUPUSER,
                KH.HACDT
            FROM
                KENHTRN KH
            WHERE
                    KH.KAICD = PKAICD
                AND KH.JGYCD = PJGYCD
                AND KH.TENCD = PTENCD
                AND KH.SHICD = PSHICD
                AND KH.HACNO = PDENNO
                AND KH.HACDT = PHACDT;
        --正常終了
        RETURN 0;
-- 例外終了
 EXCEPTION
        WHEN OTHERS THEN
        WK_FCERRCD := SQLCODE;
        WK_FCERRMG := SUBSTR('[inssirhtrn] : ' || WK_FCSTEP || ' : ' || SQLERRM, 1, 500);
        RETURN WK_FCERRCD;
        
    END INSSIRHTRN;
--仕入明細トランを登録
    FUNCTION INSSIRBTRN (
        PKAICD  IN NUMBER,
        PJGYCD  IN NUMBER,
        PJANCD  IN NUMBER,
        PTENCD  IN NUMBER,
        PSHICD  IN NUMBER,
        PUPPC   IN VARCHAR2,
        PUPUSER IN VARCHAR2
    ) RETURN INTEGER IS
    BEGIN
        IF  
            PJANCD IS NOT NULL
            AND LENGTH(PJANCD)>0     
        THEN
            INSERT INTO SIRBTRN (
                KAICD,
                JGYCD,
                TENCD,
                SHICD,
                DENSYU,
                DENNO,
                DENGYO,
                JANCD,
                BMNCD,
                HINKJ,
                KIKKJ,
                IRISU,
                ODRSU,
                SHKSU,
                SHISU,
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_START
                GENKA,
                BAIKA,
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_END
                GENKNG,
                BAIKNG,
                GKAZEI,
                BKAZEI,
                ZERIT,
                GENHON,
                GENZEI,
                BAIHON,
                BAIZEI,
                MAKDT,
                MAKTM,
                UPDT,
                UPTM,
                PGMID,
                UPPC,
                UPUSER,
                ORDER_DATE
                --2024/02/29 ADD STR SYS.koba	
               ,UNIT_MULTIPLE	
                --2024/02/29 ADD END	
            )
                SELECT
                    KB.KAICD,
                    KB.JGYCD,
                    KB.TENCD,
                    KB.SHICD,
--2024/01/11_KDP導入_HISYS_C.LIU_MOD_START
                    --kb.densyu,
                    COMCONST.CDENSYU_SIRETEGAKI,
--2024/01/11_KDP導入_HISYS_C.LIU_MOD_END
                    VDENNO,
                    KB.DENGYO,
                    KB.JANCD,
                    KB.BMNCD,
                    KB.HINKJ,
                    KB.KIKKJ,
                    KB.IRISU,
                    KB.ODRSU,
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
--                  kb.shksu,
--                  kb.shisu,
                    PKPNSU,
                    PKPNSU,
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_START
                    KB.GENTNK,
                    KB.BAITNK,
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_END
--2023/11/27_KDP導入_HISYS_C.LIU_MOD_START
--                    kb.genkng,
--                    kb.baikng,
                    --2024/02/29 UPD STR SYS.koba	
                    --PKPNSU * kb.gentnk,	
                    --PKPNSU * kb.baitnk,	
                    CASE	
                        WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_KIRIAGE    THEN COMPROC.TOROUNDUP(PKPNSU * KB.GENTNK, 0)   --切り上げ	
                        WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_KIRISUTE   THEN COMPROC.TOROUNDDOWN(PKPNSU * KB.GENTNK, 0) --切り捨て	
                        WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_SISHAGONYU THEN COMPROC.TOROUND(PKPNSU * KB.GENTNK, 0)     --四捨五入	
                    END ,	
                    CASE	
                        WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_KIRIAGE    THEN COMPROC.TOROUNDUP(PKPNSU * KB.BAITNK, 0)   --切り上げ	
                        WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_KIRISUTE   THEN COMPROC.TOROUNDDOWN(PKPNSU * KB.BAITNK, 0) --切り捨て	
                        WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_SISHAGONYU THEN COMPROC.TOROUND(PKPNSU * KB.BAITNK, 0)     --四捨五入	
                    END ,	
                    --2024/02/29 UPD END	
--2023/11/27_KDP導入_HISYS_C.LIU_MOD_END                   
                    KB.GKAZEI,
                    KB.BKAZEI,
                    --2024/02/29 UPD STR SYS.koba	
                    --kb.zerit,	
                    --kb.genhon,	
                    --kb.genzei,	
                    --kb.baihon,	
                    --kb.baizei,	
                    ZEIRT ( PKAICD	
                        , PJGYCD	
                        , ZERITKBN ( PKAICD, PJGYCD, PJANCD, DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                        , DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) ),	
                    GENHON ( V_T_ZEIKBN	
                        , V_GZHASUKBN	
                        , KB.GKAZEI	
                        , ZEIRT ( PKAICD	
                                , PJGYCD	
                                , ZERITKBN ( PKAICD, PJGYCD, PJANCD, DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                                , DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                        , CASE	
                              WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_KIRIAGE    THEN COMPROC.TOROUNDUP(PKPNSU * KB.GENTNK, 0)   --切り上げ	
                              WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_KIRISUTE   THEN COMPROC.TOROUNDDOWN(PKPNSU * KB.GENTNK, 0) --切り捨て	
                              WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_SISHAGONYU THEN COMPROC.TOROUND(PKPNSU * KB.GENTNK, 0)     --四捨五入	
                          END ),	
                    GENZEI ( V_GZHASUKBN	
                        , KB.GKAZEI	
                        , ZEIRT ( PKAICD	
                                , PJGYCD	
                                , ZERITKBN ( PKAICD, PJGYCD, PJANCD, DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                                , DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                        , CASE	
                              WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_KIRIAGE    THEN COMPROC.TOROUNDUP(PKPNSU * KB.GENTNK, 0)   --切り上げ	
                              WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_KIRISUTE   THEN COMPROC.TOROUNDDOWN(PKPNSU * KB.GENTNK, 0) --切り捨て	
                              WHEN V_GZHASUKBN = COMCONST.CDENHASUKBN_SISHAGONYU THEN COMPROC.TOROUND(PKPNSU * KB.GENTNK, 0)     --四捨五入	
                          END ),	
                    BAIHON ( V_T_ZEIKBN	
                        , V_BZHASUKBN	
                        , KB.BKAZEI	
                        , ZEIRT ( PKAICD	
                                , PJGYCD	
                                , ZERITKBN ( PKAICD, PJGYCD, PJANCD, DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                                , DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                        , CASE	
                              WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_KIRIAGE    THEN COMPROC.TOROUNDUP(PKPNSU * KB.BAITNK, 0)   --切り上げ	
                              WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_KIRISUTE   THEN COMPROC.TOROUNDDOWN(PKPNSU * KB.BAITNK, 0) --切り捨て	
                              WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_SISHAGONYU THEN COMPROC.TOROUND(PKPNSU * KB.BAITNK, 0)     --四捨五入	
                          END ),	
                    BAIZEI ( V_BZHASUKBN	
                        , KB.BKAZEI	
                        , ZEIRT ( PKAICD	
                                , PJGYCD	
                                , ZERITKBN ( PKAICD, PJGYCD, PJANCD, DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                                , DECODE(NVL(PJYUDT,0),0,PJYUDT,PJYUDT) )	
                        , CASE	
                              WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_KIRIAGE    THEN COMPROC.TOROUNDUP(PKPNSU * KB.BAITNK, 0)   --切り上げ	
                              WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_KIRISUTE   THEN COMPROC.TOROUNDDOWN(PKPNSU * KB.BAITNK, 0) --切り捨て	
                              WHEN V_BZHASUKBN = COMCONST.CDENHASUKBN_SISHAGONYU THEN COMPROC.TOROUND(PKPNSU * KB.BAITNK, 0)     --四捨五入	
                          END ),	
                    --2024/02/29 UPD END	
                    WK_SYSDATE,
                    WK_SYSEXEHMS,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_START
--                wk_sysdate,
--                wk_sysexehms,
                  0,
                  0,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_END
                    CPGMID,
                    PUPPC,
                    PUPUSER,
                    PHACDT
                    --2024/02/29 ADD STR SYS.koba	
                   ,HN.HTANI	
                    --2024/02/29 ADD END	
                FROM
                    KENBTRN KB
                    LEFT  JOIN KENHTRN KH
                    ON KB.DENNO=KH.DENNO
                     AND KB.KAICD = KH.KAICD
                     AND KB.JGYCD = KH.JGYCD
                     AND KB.TENCD = KH.TENCD
                     AND KB.SHICD = KH.SHICD
                     AND KB.DENSYU = KH.DENSYU
                    --2024/02/29 ADD STR SYS.koba	
                    LEFT  JOIN THNMST HN	
                    ON   KB.KAICD = HN.KAICD	
                     AND KB.JGYCD = HN.JGYCD	
                     AND KB.JANCD = HN.JANCD	
                     AND KB.TENCD = HN.TENCD	
                    --2024/02/29 ADD END
                WHERE
                        KB.KAICD = PKAICD
                    AND KB.JGYCD = PJGYCD
                    AND KB.JANCD = PJANCD
                    AND KB.TENCD = PTENCD
                    AND KB.SHICD = PSHICD
                    AND KH.HACNO = PDENNO
                    AND KH.HACDT = PHACDT
                    AND KB.DENGYO = PDENGYO ;

        END IF;
    --正常終了
        RETURN 0;
    EXCEPTION
        WHEN OTHERS THEN
-- 例外終了
        WK_FCERRCD := SQLCODE;
        WK_FCERRMG := SUBSTR('[inssirbtrn] : ' || WK_FCSTEP || ' : ' || SQLERRM, 1, 500);
        RETURN WK_FCERRCD;
    END INSSIRBTRN;
--履歴仕入見出を登録  
    FUNCTION INSSIRHLOG (
        PUPPC   IN VARCHAR2,
        PUPUSER IN VARCHAR2,
        PKAICD  IN NUMBER,
        PJGYCD  IN NUMBER,
        PTENCD  IN NUMBER,
        PDENNO  IN NUMBER,
        PSHICD  IN NUMBER,
        PHACDT  IN NUMBER
    ) RETURN INTEGER IS
    BEGIN
        INSERT INTO SIRHLOG (
            KAICD,
            JGYCD,
            TENCD,
            SHICD,
            DENSYU,
            PBKBN,
            NOUDT,
            KENDT,
--2023/11/15_KDP導入_HISYS_C.LIU_ADD_START
            DENDT,
--2023/11/15_KDP導入_HISYS_C.LIU_ADD_END
            --2024/02/29 ADD STR SYS.koba	
            WEEK,	
            PAYKBN,	
            PAYCNT,	
            GKAZEI,	
            BKAZEI,	
            KYAKKBN,	
            CENTERCD,	
            DTMAKKBN,	
            HACDT,	
            PRT_FLG,	
            JIT_FLG,	
            SOU_FLG,	
            GCK_FLG,	
            BIKO,	
            --2024/02/29 ADD END	
            HAICD,
            HACNO,
            KYKNO,
            ONLKBN,
            HAIPTN,
            DCHACKBN,
            HACTYPE,
            SIRSEQ,
            UPDKBN,
            MAKDT,
            MAKTM,
            UPDT,
            UPTM,
            PGMID,
            UPPC,
            UPUSER,
            DENNO,
            INPDT,
            INPTIME,
            INPTANCD,
            DATAKBN
        )
            SELECT
                SH.KAICD,
                SH.JGYCD,
                SH.TENCD,
                SH.SHICD,
                SH.DENSYU,
                SH.PBKBN,
                SH.NOUDT,
                SH.KENDT,
--2023/11/15_KDP導入_HISYS_C.LIU_ADD_START
                SH.DENDT,
--2023/11/15_KDP導入_HISYS_C.LIU_ADD_END
                --2024/02/29 ADD STR SYS.koba	
                SH.WEEK,	
                SH.PAYKBN,	
                SH.PAYCNT,	
                SH.GKAZEI,	
                SH.BKAZEI,	
                SH.KYAKKBN,	
                SH.CENTERCD,	
                SH.DTMAKKBN,	
                SH.HACDT,	
                0,	
                0,	
                0,	
                0,	
                SH.BIKO,	
                --2024/02/29 ADD END	
                SH.HAICD,
                SH.HACNO,
                SH.KYKNO,
                SH.ONLKBN,
                SH.HAIPTN,
                SH.DCHACKBN,
                SH.HACTYPE,
                SH.SIRSEQ,
                SH.UPDKBN,
                WK_SYSDATE,
                WK_SYSEXEHMS,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_START
--                wk_sysdate,
--                wk_sysexehms,
                  0,
                  0,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_END
                CPGMID,
                PUPPC,
                PUPUSER,
                SH.DENNO,
                 WK_SYSDATE,
                WK_SYSEXEHMS,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_START
--              pupuser,
                0,
--               2
                COMCONST.CDATAKBN_SHIN
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_END
            FROM
                SIRHTRN SH
            WHERE
                    SH.KAICD = PKAICD
                AND SH.SHICD　 = PSHICD
                AND SH.HACDT = PHACDT
                AND SH.JGYCD = PJGYCD
                AND SH.TENCD = PTENCD
                --2024/02/29 ADD STR SYS.koba	
                AND SH.DENNO = VDENNO	
                --2024/02/29 ADD END	
                AND SH.HACNO = PDENNO;

      --正常終了
        RETURN 0;
 -- 例外終了
   EXCEPTION
        WHEN OTHERS THEN
        WK_FCERRCD := SQLCODE;
        WK_FCERRMG := SUBSTR('[inssirhlog] : ' || WK_FCSTEP || ' : ' || SQLERRM, 1, 500);
        RETURN WK_FCERRCD;
    END INSSIRHLOG;

--履歴仕入明細の作成を行う
    FUNCTION INSSIRBLOG (
        PUPPC   IN VARCHAR2,
        PUPUSER IN VARCHAR2,
        PKAICD  IN NUMBER,
        PJGYCD  IN NUMBER,
        PTENCD  IN NUMBER,
        PDENNO  IN NUMBER
    ) RETURN INTEGER IS
    BEGIN
        INSERT INTO SIRBLOG (
            KAICD,
            JGYCD,
            TENCD,
            SHICD,
            DENSYU,
            DENNO,
            DENGYO,
            JANCD,
            BMNCD,
            --2024/02/29 ADD STR SYS.koba	
            DAICD,	
            CHUCD,	
            SHOCD,	
            --2024/02/29 ADD END	
            HINKJ,
            KIKKJ,
            IRISU,
            ODRSU,
            SHKSU,
            SHISU,
            GENKA,
            BAIKA,
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_START
            GENKNG,
            BAIKNG,
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_END
            GKAZEI,
            BKAZEI,
            ZERIT,
            GENHON,
            GENZEI,
            BAIHON,
            BAIZEI,
            MAKDT,
            MAKTM,
            UPDT,
            UPTM,
            PGMID,
            UPPC,
            UPUSER,
            --2024/02/29 ADD STR SYS.koba	
            SENDER_ID,	
            SENDER_ID_AUTHORITY,	
            RECEIVER_ID,	
            RECEIVER_ID_AUTHORITY,	
            TYPE_VERSION,	
            INSTANCE_ID,	
            MESSAGE_TYPE,	
            CREATION_DATE_TIME,	
            BUSINESS_SCOPE_ID,	
            FINAL_RECEIVER_ID,	
            UNIQUE_CREATOR_ID,	
            SENDER_SA,	
            ULTIMATE_RECEIVER_SA,	
            IMMEDIATE_RECEIVER_SA,	
            NUM_OF_TRADING_DOC,	
            PAYER_GLN,	
            BUYER_CODE,	
            BUYER_GLN,	
            BUYER_NAME,	
            BUYER_NAME_KANA,	
            ADD_TRADE_NO,	
            SHIPMENT_NO,	
            SHIP_TO_CODE,	
            SHIP_TO_GLN,	
            SHIP_TO_NAME,	
            SHIP_TO_NAME_KANA,	
            RECEIVER_GLN,	
            RECEIVER_NAME,	
            RECEIVER_NAME_KANA,	
            RECORD_OFFICE_CODE,	
            RECORD_OFFICE_GLN,	
            RECORD_OFFICE_NAME_KANA,	
            DISPLAY_SPACE_CODE,	
            DISPLAY_SPACE_NAME,	
            DISPLAY_SPACE_NAME_KANA,	
            PAYEE_CODE,	
            PAYEE_GLN,	
            PAYEE_NAME,	
            PAYEE_NAME_KANA,	
            SELLER_GLN,	
            SELLER_NAME,	
            SELLER_NAME_KANA,	
            BRANCH_NO,	
            SHIP_LOCATION_CODE,	
            SHIP_FROM_GLN,	
            MAKER_CODE_FOR_RECEIVING,	
            DELIVERY_SLIP_NO,	
            ROUTE_CODE,	
            BIN,	
            STOCK_TRANSFER_CODE,	
            DELIVERY_CODE,	
            DELIVERY_TIME,	
            BARCODE_PRINT,	
            CATEGORY_NAME_PRINT1,	
            CATEGORY_NAME_PRINT2,	
            RECEIVER_ADDR_NAME,	
            LABEL_FREE_TEXT,	
            LABEL_FREE_TEXT_KANA,	
            ORDER_DATE,	
            DELIVERY_DATE,	
            DELIVERY_DATE_TO_RECEIVER,	
            REVICED_DLVR_DATE,	
            REVICED_DLVR_DATE_TO_RECEIVER,	
            RECORD_DATE,	
            CAMPAIGN_START_DATE,	
            CAMPAIGN_END_DATE,	
            GOODS_CLASSIFICATION_CODE,	
            ORDER_CLASSIFICATION_CODE,	
            SN_REQUEST_CODE,	
            TRADE_NO_REQUEST_CODE,	
            EOSKBN,	
            PBKBN,	
            TEMPERATURE_CODE,	
            LIQUOR_CODE,	
            PACKAGE_CODE,	
            VARIABLE_MEASURE_ITEM_CODE,	
            TRADE_TYPE_CODE,	
            PAPER_FORM_LESS_CODE,	
            TAX_TYPE_CODE,	
            TAX_RATE,	
            FREE_TEXT,	
            FREE_TEXT_KANA,	
            NET_PRICE_TOTAL,	
            SELLING_PRICE_TOTAL,	
            TAX_TOTAL,	
            ITEM_TOTAL,	
            UNIT_TOTAL,	
            UNIT_WEIGHT_TOTAL,	
            ADD_LINE_NO,	
            ORIGIN_TRADE_NO,	
            ORIGIN_LINE_NO,	
            SHIPMENT_LINE_NO,	
            DELIVERY_SCHEDULED_DATE,	
            DELIVERY_DEADLINE_DATE,	
            CENTER_DLVR_INSTRUCTION_CODE,	
            MAKERCD,	
            ITEM_CODE_GTIN,	
            SUPPLIER_ITEM_CODE,	
            SHIPMENT_ITEM_CODE,	
            ORDER_ITEM_CODE_TYPE,	
            ITEM_NAME_KANA,	
            KIKAK_KANA,	
            PREFECTURE_CODE,	
            COUNTRY_CODE,	
            FIELD_NAME,	
            WATER_AREA_CODE,	
            WATER_AREA_NAME,	
            AREA_OF_ORIGIN,	
            ITEM_GRADE,	
            ITEM_CLASS,	
            BRAND,	
            ITEM_PR,	
            BIO_CODE,	
            BREED_CODE,	
            CULTIVATION_CODE,	
            DEFROST_CODE,	
            ITEM_PRESERVATION_CODE,	
            ITEM_SHAPE_CODE,	
            USE,	
            STATUTORY_CLASSIFICATION_CODE,	
            COLOR_CODE,	
            COLOR_NAME,	
            COLOR_NAME_KANA,	
            SIZE_CODE,	
            SIZE_NAME,	
            SIZE_NAME_KANA,	
            ITEM_TAX,	
            UNIT_MULTIPLE,	
            ORDER_UNIT_QUANTITY,	
            UNIT_OF_MEASURE_CODE,	
            PACKAGE_INDICATOR_CODE,	
            ORDER_WEIGHT,	
            UNIT_WEIGHT,	
            UNIT_WEIGHT_CODE,	
            ITEM_WEIGHT,	
            SHIPMENT_UNIT_QUANTITY,	
            SHIPMENT_WEIGHT,	
            RECEIVED_UNIT_QUANTITY,	
            RECEIVED_WEIGHT,	
            REASON_CODE,	
            HINCD_SAL,	
            BMNCD_SAL,	
            KEI_YM,	
            OPENDT,	
            IDNO,	
            LOTNO,	
            --2024/02/29 ADD END	
            INPDT,
            INPTIME,
            INPTANCD,
            DATAKBN
        )
            SELECT
                SB.KAICD,
                SB.JGYCD,
                SB.TENCD,
                SB.SHICD,
                SB.DENSYU,
                SB.DENNO,
                SB.DENGYO,
                SB.JANCD,
                SB.BMNCD,
                --2024/02/29 ADD STR SYS.koba
                SB.DAICD,	
                SB.CHUCD,	
                SB.SHOCD,
                --2024/02/29 ADD END	
                SB.HINKJ,
                SB.KIKKJ,
                SB.IRISU,
                SB.ODRSU,
                SB.SHKSU,
                SB.SHISU,
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_START 
                SB.GENKA,
                SB.BAIKA,
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_START
                SB.GENKNG,
                SB.BAIKNG,
                SB.GKAZEI,
                SB.BKAZEI,
                SB.ZERIT,
                SB.GENHON,
                SB.GENZEI,
                SB.BAIHON,
                SB.BAIZEI,
                WK_SYSDATE,
                WK_SYSEXEHMS,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_START
--                wk_sysdate,
--                wk_sysexehms,
                  0,
                  0,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_END
                CPGMID,
                PUPPC,
                PUPUSER,
                --2024/02/29 ADD STR SYS.koba	
                SB.SENDER_ID,	
                SB.SENDER_ID_AUTHORITY,	
                SB.RECEIVER_ID,	
                SB.RECEIVER_ID_AUTHORITY,	
                SB.TYPE_VERSION,	
                SB.INSTANCE_ID,	
                SB.MESSAGE_TYPE,	
                SB.CREATION_DATE_TIME,	
                SB.BUSINESS_SCOPE_ID,	
                SB.FINAL_RECEIVER_ID,	
                SB.UNIQUE_CREATOR_ID,	
                SB.SENDER_SA,	
                SB.ULTIMATE_RECEIVER_SA,	
                SB.IMMEDIATE_RECEIVER_SA,	
                SB.NUM_OF_TRADING_DOC,	
                SB.PAYER_GLN,	
                SB.BUYER_CODE,	
                SB.BUYER_GLN,	
                SB.BUYER_NAME,	
                SB.BUYER_NAME_KANA,	
                SB.ADD_TRADE_NO,	
                SB.SHIPMENT_NO,	
                SB.SHIP_TO_CODE,	
                SB.SHIP_TO_GLN,	
                SB.SHIP_TO_NAME,	
                SB.SHIP_TO_NAME_KANA,	
                SB.RECEIVER_GLN,	
                SB.RECEIVER_NAME,	
                SB.RECEIVER_NAME_KANA,	
                SB.RECORD_OFFICE_CODE,	
                SB.RECORD_OFFICE_GLN,	
                SB.RECORD_OFFICE_NAME_KANA,	
                SB.DISPLAY_SPACE_CODE,	
                SB.DISPLAY_SPACE_NAME,	
                SB.DISPLAY_SPACE_NAME_KANA,	
                SB.PAYEE_CODE,	
                SB.PAYEE_GLN,	
                SB.PAYEE_NAME,	
                SB.PAYEE_NAME_KANA,	
                SB.SELLER_GLN,	
                SB.SELLER_NAME,	
                SB.SELLER_NAME_KANA,	
                SB.BRANCH_NO,	
                SB.SHIP_LOCATION_CODE,	
                SB.SHIP_FROM_GLN,	
                SB.MAKER_CODE_FOR_RECEIVING,	
                SB.DELIVERY_SLIP_NO,	
                SB.ROUTE_CODE,	
                SB.BIN,	
                SB.STOCK_TRANSFER_CODE,	
                SB.DELIVERY_CODE,	
                SB.DELIVERY_TIME,	
                SB.BARCODE_PRINT,	
                SB.CATEGORY_NAME_PRINT1,	
                SB.CATEGORY_NAME_PRINT2,	
                SB.RECEIVER_ADDR_NAME,	
                SB.LABEL_FREE_TEXT,	
                SB.LABEL_FREE_TEXT_KANA,	
                SB.ORDER_DATE,	
                SB.DELIVERY_DATE,	
                SB.DELIVERY_DATE_TO_RECEIVER,	
                SB.REVICED_DLVR_DATE,	
                SB.REVICED_DLVR_DATE_TO_RECEIVER,	
                SB.RECORD_DATE,	
                SB.CAMPAIGN_START_DATE,	
                SB.CAMPAIGN_END_DATE,	
                SB.GOODS_CLASSIFICATION_CODE,	
                SB.ORDER_CLASSIFICATION_CODE,	
                SB.SN_REQUEST_CODE,	
                SB.TRADE_NO_REQUEST_CODE,	
                SB.EOSKBN,	
                SB.PBKBN,	
                SB.TEMPERATURE_CODE,	
                SB.LIQUOR_CODE,	
                SB.PACKAGE_CODE,	
                SB.VARIABLE_MEASURE_ITEM_CODE,	
                SB.TRADE_TYPE_CODE,	
                SB.PAPER_FORM_LESS_CODE,	
                SB.TAX_TYPE_CODE,	
                SB.TAX_RATE,	
                SB.FREE_TEXT,	
                SB.FREE_TEXT_KANA,	
                SB.NET_PRICE_TOTAL,	
                SB.SELLING_PRICE_TOTAL,	
                SB.TAX_TOTAL,	
                SB.ITEM_TOTAL,	
                SB.UNIT_TOTAL,	
                SB.UNIT_WEIGHT_TOTAL,	
                SB.ADD_LINE_NO,	
                SB.ORIGIN_TRADE_NO,	
                SB.ORIGIN_LINE_NO,	
                SB.SHIPMENT_LINE_NO,	
                SB.DELIVERY_SCHEDULED_DATE,	
                SB.DELIVERY_DEADLINE_DATE,	
                SB.CENTER_DLVR_INSTRUCTION_CODE,	
                SB.MAKERCD,	
                SB.ITEM_CODE_GTIN,	
                SB.SUPPLIER_ITEM_CODE,	
                SB.SHIPMENT_ITEM_CODE,	
                SB.ORDER_ITEM_CODE_TYPE,	
                SB.ITEM_NAME_KANA,	
                SB.KIKAK_KANA,	
                SB.PREFECTURE_CODE,	
                SB.COUNTRY_CODE,	
                SB.FIELD_NAME,	
                SB.WATER_AREA_CODE,	
                SB.WATER_AREA_NAME,	
                SB.AREA_OF_ORIGIN,	
                SB.ITEM_GRADE,	
                SB.ITEM_CLASS,	
                SB.BRAND,	
                SB.ITEM_PR,	
                SB.BIO_CODE,	
                SB.BREED_CODE,	
                SB.CULTIVATION_CODE,	
                SB.DEFROST_CODE,	
                SB.ITEM_PRESERVATION_CODE,	
                SB.ITEM_SHAPE_CODE,	
                SB.USE,	
                SB.STATUTORY_CLASSIFICATION_CODE,	
                SB.COLOR_CODE,	
                SB.COLOR_NAME,	
                SB.COLOR_NAME_KANA,	
                SB.SIZE_CODE,	
                SB.SIZE_NAME,	
                SB.SIZE_NAME_KANA,	
                SB.ITEM_TAX,	
                SB.UNIT_MULTIPLE,	
                SB.ORDER_UNIT_QUANTITY,	
                SB.UNIT_OF_MEASURE_CODE,	
                SB.PACKAGE_INDICATOR_CODE,	
                SB.ORDER_WEIGHT,	
                SB.UNIT_WEIGHT,	
                SB.UNIT_WEIGHT_CODE,	
                SB.ITEM_WEIGHT,	
                SB.SHIPMENT_UNIT_QUANTITY,	
                SB.SHIPMENT_WEIGHT,	
                SB.RECEIVED_UNIT_QUANTITY,	
                SB.RECEIVED_WEIGHT,	
                SB.REASON_CODE,	
                SB.HINCD_SAL,	
                SB.BMNCD_SAL,	
                SB.KEI_YM,	
                SB.OPENDT,	
                SB.IDNO,	
                SB.LOTNO,	
                --2024/02/29 ADD END	
                WK_SYSDATE,
                WK_SYSEXEHMS,
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_START
--              pupuser,
                0,
--               2
                COMCONST.CDATAKBN_SHIN
--2023/11/15_KDP導入_HISYS_C.LIU_MOD_END
            FROM
                SIRBTRN SB
                LEFT  JOIN SIRHTRN SH
                ON SB.DENNO=SH.DENNO
                AND  SB.KAICD = SH.KAICD
                AND SB.JGYCD = SH.JGYCD
                AND SB.TENCD = SH.TENCD
                AND SB.SHICD = SH.SHICD
                AND SB.DENSYU = SH.DENSYU
            WHERE
                    SB.KAICD = PKAICD
                AND SB.JGYCD = PJGYCD
                AND SB.JANCD = PJANCD
                AND SB.TENCD = PTENCD
                AND SB.SHICD = PSHICD
                AND SH.HACNO = PDENNO
                AND SH.HACDT = PHACDT
                --2024/02/29 ADD STR SYS.koba	
                AND SB.DENNO = VDENNO	
                --2024/02/29 ADD END	
                AND SB.DENGYO = PDENGYO;

      --正常終了
        RETURN 0;
    EXCEPTION
        WHEN OTHERS THEN
-- 例外終了
        WK_FCERRCD := SQLCODE;
        WK_FCERRMG := SUBSTR('[inssirblog] : ' || WK_FCSTEP || ' : ' || SQLERRM, 1, 500);
        RETURN WK_FCERRCD;
    END INSSIRBLOG;

--検品明細トランの更新
FUNCTION UPDKENBTRN (
    PUPPC   IN VARCHAR2,
    PUPUSER IN VARCHAR2,
    PKAICD  IN NUMBER,
    PJGYCD  IN NUMBER,
    PTENCD  IN NUMBER,
    PDENNO  IN NUMBER,
    PHACDT  IN NUMBER,
    PUPDT   IN NUMBER,
    PUPTM   IN NUMBER,
    PPGMID  IN VARCHAR2
) RETURN INTEGER IS 
    V_KPNFLG  NUMBER;
    --2023/10/13_KDP導入_HISYS_C.LIU_ADD_START
    VKPNFLG   NUMBER;
    CNT#01   NUMBER;
    V_DENNO   NUMBER;
    --2023/10/13_KDP導入_HISYS_C.LIU_ADD_END
BEGIN
    --2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
--    SELECT KPNFLG into v_KPNFLG --自動欠品フラグ、伝票番号を取得する
    SELECT KPNFLG,DENNO 
    INTO VKPNFLG,V_DENNO --自動欠品フラグ、伝票番号を取得する
    --2023/10/13_KDP導入_HISYS_C.LIU_MOD_END 
    FROM
        KENHTRN 
    WHERE
            KAICD = PKAICD
        AND JGYCD = PJGYCD
        AND TENCD = PTENCD
        AND HACNO = PDENNO
        AND SHICD = PSHICD;
    --2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
    SELECT COUNT (*) INTO CNT#01 
      FROM (
    SELECT TENCD
          ,DENNO
      FROM KENHTRN
     WHERE TENCD = PTENCD
       AND SHICD = PSHICD
       AND DENNO = V_DENNO
       AND KPNFLG = 0);

       V_KPNFLG := CNT#01;
--    --自動欠品フラグが0の場合更新を行う
--    IF 0 =  v_KPNFLG THEN
    UPDATE KENBTRN KB
    SET 
--        HACZSU = HACZSU - PKPNSU, --発注残数　＝　発注残数　ー　por検品数
--        SHISU = SHISU+PKPNSU,--仕入数量　＝　仕入数量　+　por検品数
        SHKSU    =  SHKSU  + PKPNSU,
        SHISU    = SHISU + PKPNSU,
--2024/02/29 UPD STR	
--        HACZSU = CASE WHEN v_KPNFLG > 0 THEN (ODRSU-SHISU) -  PKPNSU --発注残数　＝　発注残数　ー　por検品数
--                      ELSE DECODE(SIGN(ODRSU - (SHISU + PKPNSU)),1,ODRSU - (SHISU + PKPNSU),0,0,-1,0)
--                          END,
        HACZSU = DECODE(SIGN(ODRSU - (SHISU + PKPNSU)),1,ODRSU - (SHISU + PKPNSU),0,0,-1,0),
--2024/02/29 UPD END
        --2023/11/27_KDP導入_HISYS_C.LIU_DEL_START
--        GENKNG = (SHISU + PKPNSU)* GENTNK,
--        BAIKNG = (SHISU + PKPNSU)* BAITNK,
        --2023/11/27_KDP導入_HISYS_C.LIU_DEL_END
        --2023/10/13_KDP導入_HISYS_C.LIU_MOD_END
        UPDT = PUPDT,
        UPTM = PUPTM,
        PGMID = PPGMID,
        UPPC = PUPPC,
        UPUSER = PUPUSER
         
     WHERE KAICD  = PKAICD
	  AND JGYCD  = PJGYCD
	  AND TENCD  = PTENCD
      --2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
      --AND DENNO = pdenno
	  AND DENNO = V_DENNO
      AND HACZSU > 0
      --2023/10/13_KDP導入_HISYS_C.LIU_MOD_END
      --AND DENGYO = pDENGYO
      AND DENGYO = PDENGYO;	
      --2024/02/29 DEL STR SYS.koba	
      --AND (select hacdt from kenhtrn kh 	
      --            where kb.denno=kh.denno	
      --            and kb.kaicd = kh.kaicd	
      --             and kb.jgycd = kh.jgycd	
      --             and kb.tencd = kh.tencd	
      --             and kb.shicd = kh.shicd	
      --             and kb.densyu = kh.densyu) = phacdt;	
      --2024/02/29 DEL END	

    --正常終了
    RETURN 0;  
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
--    END IF;
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_END
    --正常終了 更新しない
    RETURN 0; 
    EXCEPTION
        WHEN OTHERS THEN
-- 例外終了
        WK_FCERRCD := SQLCODE;
        WK_FCERRMG := SUBSTR('[updkenbtrn] : ' || WK_FCSTEP || ' : ' || SQLERRM, 1, 500);
        RETURN WK_FCERRCD;
END UPDKENBTRN;

--検品見出しトランの更新
FUNCTION UPDKENHTRN(
         PUPPC IN VARCHAR2
        ,PUPUSER IN VARCHAR2
        ,PKAICD IN NUMBER
        ,PJGYCD IN NUMBER
        ,PTENCD IN NUMBER
        ,PSHICD IN NUMBER
        ,PDENNO IN NUMBER
        ,PHACDT IN NUMBER
        ,PUPDT   IN NUMBER
        ,PUPTM   IN NUMBER
        ,PPGMID  IN VARCHAR2)
     RETURN INTEGER IS BEGIN
     
--2024/01/12_KDP導入_HISYS_C.LIU_MOD_START     
--     IF 1 =  comparedResult THEN
       IF ISLAST = 1 THEN
       VSHRFLG :=COMCONST.CSHRFLG_SHORIZUMI;
--2024/01/12_KDP導入_HISYS_C.LIU_MOD_END  
     FOR VKBCUR IN KBCUR LOOP
     --2023/10/13_KDP導入_HISYS_C.LIU_MOD_START
--        IF  vkbcur.haczsu<>0 THEN
--           VSHRFLG :=0;
--           EXIT;
--        END IF;
--2024/01/12_KDP導入_HISYS_C.LIU_DEL_START 
--       VSHRFLG :=COMCONST.CSHRFLG_SHORIZUMI;
--2024/01/12_KDP導入_HISYS_C.LIU_DEL_END 
       IF VKBCUR.ZANSU <> 0 THEN 
            VSHRFLG := COMCONST.CSHRFLG_MISHORI;
        ELSE -- 欠品区分が「2：欠品あり」のデータが全納になった場合、欠品区分を「3：遅納」に更新する
            IF VKBCUR.KPNKBN = 2 THEN -- COMCONSTでSH28欠品区分はまだ未記入ので、NUMBERを使っておく
                UPDATE KENBTRN
                   SET KPNKBN = 3 
                 WHERE KAICD = PKAICD
                   AND JGYCD = PJGYCD
                   AND TENCD = PTENCD
                   AND SHICD = PSHICD
                   AND DENNO = VKBCUR.DENNO
                   AND JANCD = VKBCUR.JANCD;
            END IF;  
        END IF; 
     END LOOP;
    --2023/10/13_KDP導入_HISYS_C.LIU_MOD_END
     UPDATE KENHTRN
     SET KENDT = PJYUDT, --検収日　＝　受領日
        SHRFLG =  VSHRFLG,
        UPDT = PUPDT,
        UPTM = PUPTM,
        PGMID = PPGMID,
        UPPC = PUPPC,
        UPUSER = PUPUSER
     WHERE KAICD  = PKAICD
	   AND JGYCD  = PJGYCD
	   AND TENCD  = PTENCD
       AND SHICD  = PSHICD
	   AND HACNO  = PDENNO 
       AND HACDT = PHACDT;
     END IF;
        --正常終了
        RETURN 0; 
 EXCEPTION
        WHEN OTHERS THEN
-- 例外終了
        WK_FCERRCD := SQLCODE;
        WK_FCERRMG := SUBSTR('[UpdKENHTRN] : ' || WK_FCSTEP || ' : ' || SQLERRM, 1, 500);
        RETURN WK_FCERRCD;
    END UPDKENHTRN;

--stamp7.POR入荷検品トランの更新

FUNCTION UPDPORTRN(
         PUPPC IN VARCHAR2
        ,PUPUSER IN VARCHAR2
        ,PUPDT   IN NUMBER
        ,PUPTM   IN NUMBER
        ,PPGMID  IN VARCHAR2)
         RETURN INTEGER IS BEGIN
    UPDATE PORTRN
    SET FINFLG = COMCONST.CPORKRFLG_KEIJYOZIMI,
        UPDT = PUPDT,
        UPTM = PUPTM,
        PGMID = PPGMID,
        UPPC = PUPPC,
        UPUSER = PUPUSER
        
     WHERE FINFLG = COMCONST.CPORKRFLG_KEIJYOSHORITYU;--完了フラグ2：計上処理中 -> 3：計上済み

        --正常終了
        RETURN 0;
 EXCEPTION
        WHEN OTHERS THEN
-- 例外終了
        WK_FCERRCD := SQLCODE;
        WK_FCERRMG := SUBSTR('[updportrn] : ' || WK_FCSTEP || ' : ' || SQLERRM, 1, 500);
        RETURN WK_FCERRCD;
    END UPDPORTRN;
    

/*============================================================================*/
/* 処理本体                                                     */
/*============================================================================*/
BEGIN
    
  -- 0. 変数初期化
    WK_PROC := 'SHBAT0550C';
    WK_STEP := '処理日時取得';
    WK_SYSDATE := TO_NUMBER ( TO_CHAR(SYSDATE, 'YYYYMMDD') );
    WK_SYSEXEHMS := TO_NUMBER ( TO_CHAR(SYSDATE, 'HH24MISS') );
    --2024/02/29 ADD STR SYS.koba
    SELECT DENHASUKBN,T_ZEIKBN,BZHASUKBN,GZHASUKBN INTO V_DENHASUKBN,V_T_ZEIKBN,V_BZHASUKBN,V_GZHASUKBN FROM CNTMST;
    --2024/02/29 ADD END
    IF COMPAREDRESULT = 1 THEN
    VDENNO := FUNC_GETDENNO_NOCD(PKAICD,PJGYCD,COMCONST.CMSTDENKBN_SIRTEGAKI,WK_ERRMSG);--伝票番号の採番
    --2024/02/29 UPD STR SYS.koba	
    --else  select denno into  vdenno from sirhtrn sh WHERE	
    --                sh.kaicd = pkaicd	
    --            AND sh.jgycd = pjgycd	
    --            AND sh.tencd = ptencd	
    --            AND sh.shicd = pshicd	
    --            AND sh.hacno = pdenno	
    --            AND sh.hacdt = phacdt;	
    ELSE 	
        SELECT	
            DENNO INTO  VDENNO	
        FROM	
            (	
            SELECT	
                KAICD,	
                JGYCD,	
                TENCD,	
                SHICD,	
                DENNO	
            FROM 	
                SIRHTRN	
            WHERE	
                KAICD = PKAICD	
            AND JGYCD = PJGYCD	
            AND TENCD = PTENCD	
            AND SHICD = PSHICD	
            AND HACNO = PDENNO	
            AND HACDT = PHACDT	
            ORDER BY HACNO ,SIRSEQ DESC	
            )	
        WHERE	
            ROWNUM = 1;	
    --2024/02/29 UPD END	
    END IF;	
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_START     
--   --1. 検品明細トランの更新
--    wk_step := '検品明細トランの更新';
--    IF 0 <> updkenbtrn(puppc, pupuser, pkaicd, pjgycd, ptencd,
--                      pdenno, phacdt, wk_sysdate, wk_sysexehms, wk_proc) THEN
--            ROLLBACK;
--            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
--            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
--            RETURN;
--
--    END IF;
--   
--  -- 2. 検品見出しトランの更新
--    IF comparedresult = 1 THEN --　※1件前の処理データと「店舗コード」「発注番号」「発注日」のいずれかが異なる場合のみ
--    wk_step := '検品見出しトランの更新';
--    VSHRFLG :=0;
--    IF 0 <> updkenhtrn(puppc, pupuser, pkaicd, pjgycd, ptencd, pSHICD,
--                      pdenno, pHACDT, wk_sysdate, wk_sysexehms, wk_proc) THEN
--       ROLLBACK;
--            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
--            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
--            RETURN;
--
--    END IF;
--    END IF;
-- 1. 仕入見出しトランを登録
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_END 
    IF COMPAREDRESULT = 1 THEN --　※1件前の処理データと「店舗コード」「発注番号」「発注日」のいずれかが異なる場合のみ
    WK_STEP := '仕入見出しトランを登録';
    IF 0 <> INSSIRHTRN(PKAICD, PJGYCD, PDENNO, PTENCD, PUPPC,
    --2024/02/29 UPD STR SYS.koba	
--                      pupuser, comparedresult, pshicd, phacdt) THEN
                      'SVJOB', COMPAREDRESULT, PSHICD, PHACDT) THEN	
    --2024/02/29 UPD END
        ROLLBACK;
            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
            RETURN;
    END IF;
    END IF;
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_START    
-- 2. 仕入明細トランを登録
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_END 
    WK_STEP := '仕入明細トランを登録';
 IF 0 <> INSSIRBTRN(PKAICD, PJGYCD, PJANCD, PTENCD, PSHICD,
 --2024/02/29 UPD STR SYS.koba	
--                      puppc, pupuser) THEN
                      PUPPC, 'SVJOB') THEN	
 --2024/02/29 UPD END
    ROLLBACK;
            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
            RETURN;
    END IF;
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_START   
-- 3. 履歴仕入見出を登録する
--2023/10/13_KDP導入_HISYS_C.LIU_MOD_END 
    IF COMPAREDRESULT = 1 THEN --　※1件前の処理データと「店舗コード」「発注番号」「発注日」のいずれかが異なる場合のみ
    WK_STEP := '履歴仕入見出を登録';
     --2024/02/29 UPD STR SYS.koba	
--    IF 0 <> inssirhlog(puppc, pupuser, pkaicd, pjgycd, ptencd,
    IF 0 <> INSSIRHLOG(PUPPC, 'SVJOB', PKAICD, PJGYCD, PTENCD,
    --2024/02/29 UPD END
                      PDENNO, PSHICD, PHACDT) THEN
       ROLLBACK;
            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
            RETURN;
    END IF;
    END IF;
 --2023/10/13_KDP導入_HISYS_C.LIU_MOD_START    
  -- 4. 履歴仕入明細を登録する
  --2023/10/13_KDP導入_HISYS_C.LIU_MOD_END 
    WK_STEP := '履歴仕入明細を登録';
    --2024/02/29 UPD STR SYS.koba	
--    IF 0 <> inssirblog(puppc, pupuser, pkaicd, pjgycd, ptencd,
    IF 0 <> INSSIRBLOG(PUPPC, 'SVJOB', PKAICD, PJGYCD, PTENCD,
    --2024/02/29 UPD END
                      PDENNO) THEN
        ROLLBACK;
            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
            RETURN;
    END IF;
   --2023/10/13_KDP導入_HISYS_C.LIU_ADD_START       
   --5. 検品明細トランの更新
    WK_STEP := '検品明細トランの更新';
    --2024/02/29 UPD STR SYS.koba	
--    IF 0 <> updkenbtrn(puppc, pupuser, pkaicd, pjgycd, ptencd,
        IF 0 <> UPDKENBTRN(PUPPC, 'SVJOB', PKAICD, PJGYCD, PTENCD,
        --2024/02/29 UPD END
                      PDENNO, PHACDT, WK_SYSDATE, WK_SYSEXEHMS, WK_PROC) THEN
            ROLLBACK;
            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
            RETURN;

    END IF;
   
  -- 6. 検品見出しトランの更新
--2024/01/12_KDP導入_HISYS_C.LIU_MOD_START
--    IF comparedresult = 1 THEN --　※1件前の処理データと「店舗コード」「発注番号」「発注日」のいずれかが異なる場合のみ
    IF ISLAST = 1 THEN    --　※1件後の処理データと「店舗コード」「発注番号」「発注日」のいずれかが異なる場合のみ
--2024/01/12_KDP導入_HISYS_C.LIU_MOD_END
    WK_STEP := '検品見出しトランの更新';
--2024/01/12_KDP導入_HISYS_C.LIU_DEL_START
--    VSHRFLG :=0;
--2024/01/12_KDP導入_HISYS_C.LIU_DEL_END
--2024/02/29 UPD STR SYS.koba	
--    IF 0 <> updkenhtrn(puppc, pupuser, pkaicd, pjgycd, ptencd, pSHICD,
    IF 0 <> UPDKENHTRN(PUPPC, 'SVJOB', PKAICD, PJGYCD, PTENCD, PSHICD,
    --2024/02/29 UPD END
                      PDENNO, PHACDT, WK_SYSDATE, WK_SYSEXEHMS, WK_PROC) THEN
       ROLLBACK;
            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
            RETURN;

    END IF;
    END IF;
--2023/10/13_KDP導入_HISYS_C.LIU_ADD_END 
 -- 7. POR入荷検品トランの更新
    WK_STEP := 'POR入荷検品トランの更新';
    --2024/02/29 UPD STR SYS.koba
--    IF 0 <> updportrn(puppc, pupuser, wk_sysdate, wk_sysexehms, wk_proc) THEN
 IF 0 <> UPDPORTRN(PUPPC, 'SVJOB', WK_SYSDATE, WK_SYSEXEHMS, WK_PROC) THEN
 --2024/02/29 UPD END
        ROLLBACK;
            WK_ERRMSG := SUBSTR(WK_STEP || ':' || WK_FCERRMG, 1, 500);
            OPEN CUR FOR SELECT WK_ERRMSG AS ERRMSG FROM DUAL;
            RETURN;
    END IF;

-- 8. 当日単品実績マスタの更新を行う
    WK_STEP := '当日単品実績マスタの更新を行う'; 
--2023/10/26_KDP導入_HISYS_C.LIU_ADD_START   
IF ISLAST = 1 THEN  --　※1件後の処理データと「店舗コード」「発注番号」「発注日」のいずれかが異なる場合のみ
--2023/10/26_KDP導入_HISYS_C.LIU_ADD_END   
FOR VSHCUR IN SHCUR LOOP
    PS_SHENT0520C01U004(CUR, VSHCUR.KAICD, VSHCUR.JGYCD,PJOBDT,VSHCUR.TENCD,
                       VSHCUR.SHICD, VSHCUR.DENNO, COMCONST.CDATAKBN_SHIN, WK_SYSDATE, WK_SYSEXEHMS,
                       --2024/02/29 UPD STR SYS.koba
--                       cpgmid, puppc, pupuser);
                         CPGMID, PUPPC, 'SVJOB');
                --2024/02/29 UPD END
END LOOP;
END IF;
WK_STEP := '戻り値セット';
    OPEN CUR FOR SELECT '' AS ERRMSG FROM DUAL;
    RETURN;

END PB_SHBAT0550C_030_11;