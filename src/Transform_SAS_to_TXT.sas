
/* ----------------------------------------liusheng-----批量转换SAS文件为txt格式------------------------------- */
%macro Transform_SAS_to_TXT(
							input_dir = %str(),
							output_dir = %str(),
							full_text_yn = 0,
							start_marker = %str(SUBMIT BEGIN),
							end_marker   = %str(SUBMIT END)
							);

/* 
		input_dir 		:  需转换的SAS文件所在文件夹地址
		output_dir		:  存放转换后TXT文件的文件夹地址
		full_text_yn	:  原始文件是否全文输出？（1-是，0-否；默认为0-否）
		start_marker 	:  开始截取的标识符号，默认为“SUBMIT BEGIN”，当 full_text_yn=0 时生效
		end_marker   	:  截取结束的标识符号，默认为“SUBMIT END”，当 full_text_yn=0 时生效
*/



/* ------------------检查输入、输出目录----------------- */
data _null_;
    length inpath outpath $2000;
    inpath = symget('input_dir');
    outpath = symget('output_dir');

    /* 用 DOPEN 检查输入目录，避免 FILEEXIST 对目录判断不稳定 */
    rc_in = filename('checkin', inpath);
    did = dopen('checkin');
    if did > 0 then do;
        put "NOTE: 输入目录存在: " inpath;
        call symputx('input_exists', '1');
        rc_close = dclose(did);
    end;
    else do;
        put "WARNING: 输入的SAS文件所在目录无法打开 -> " inpath;
        call symputx('input_exists', '0');
    end;
    rc_clear = filename('checkin');

    if fileexist(outpath) then do;
        put "NOTE: 输出目录存在: " outpath;
        call symputx('output_exists', '1');
    end;
    else do;
        put "WARNING: 输出的存放转换后TXT文件目录不存在 -> " outpath;
        put "WARNING: 请确保该目录已手动创建，否则程序将无法写入TXT文件。";
        call symputx('output_exists', '0');
    end;
run;

%if &input_exists = 0 or &output_exists = 0 %then %do;
    %put ERROR: 由于目录不存在或无法打开，宏将退出，不执行批量转换。;
    %return;
%end;

/* ------------------通过 DOPEN/DREAD 获取 SAS 文件清单------------------ */
data _SAS_filelist;
    length filepath $2000 filename $512 inputpath $2000;
    inputpath = symget('input_dir');

    rc = filename('indir', inputpath);
    did = dopen('indir');

    if did <= 0 then do;
        put "ERROR: 无法打开输入目录: " inputpath;
        stop;
    end;

    do i = 1 to dnum(did);
        filename = dread(did, i);
        if lowcase(scan(filename, -1, '.')) = 'sas' then do;
            filepath = catx('\', inputpath, filename);
            output;
        end;
    end;

    rc_close = dclose(did);
    rc_clear = filename('indir');

    keep filepath filename;
run;

/* 检查是否找到 SAS 文件 */
data _null_;
    if 0 then set _SAS_filelist nobs=n;
    call symputx('sas_file_count', n);
    if n=0 then put "WARNING: 输入目录中未找到 SAS 文件。";
run;

%if &sas_file_count = 0 %then %do;
    %put WARNING: 未找到SAS文件，宏结束。;
    %return;
%end;

/* ------------------------------全文转换------------------------------ */
%if &full_text_yn = 1 %then %do;
    data _null_;
        set _SAS_filelist;
        length outpath $2000 line $32767 basename $512 outputdir $2000 readpath $2000;
        outputdir = symget('output_dir');

        /* 去除文件名末尾 .sas */
        basename = substr(filename, 1, lengthn(filename)-4);
        outpath = cats(outputdir, '\', basename, '.txt');

        put "处理文件: " filepath;
        put "输出文件: " outpath;

        readpath=filepath;
        file outref filevar=outpath;
        infile inref filevar=readpath end=eof truncover;
        do until(eof);
            input line $char32767.;
            put line;
        end;
    run;

    %put NOTE: 所有文件均按照原SAS文件全文转换为TXT文件.;
    proc delete data=_SAS_filelist;
    quit;
%end;

/* ------------------------按截取标识转换------------------------ */
%else %if &full_text_yn = 0 %then %do;

    /* 第一遍：逐文件扫描标识，记录每个文件的标识情况 */
    data _Temp_tol_markers;
        set _SAS_filelist;
        length line $32767 readpath $2000;
        has_start_markers = 0;
        has_end_markers = 0;

        readpath=filepath;
        infile inref filevar=readpath end=eof truncover;
        do until(eof);
            input line $char32767.;
            if find(upcase(line), upcase("&start_marker.")) then
                has_start_markers = 1;
            if find(upcase(line), upcase("&end_marker.")) then
                has_end_markers = 1;
        end;
        output;
        keep filepath filename has_start_markers has_end_markers;
    run;

    /* 第二遍：根据标识情况逐文件输出 */
    data _null_;
        set _Temp_tol_markers;
        length outpath $2000 line $32767 basename $512 outputdir $2000 readpath $2000;
        outputdir = symget('output_dir');
        basename = substr(filename, 1, lengthn(filename)-4);
        outpath = cats(outputdir, '\', basename, '.txt');

        started = 0;
        all_output = (has_start_markers = 0);

        put "处理文件: " filepath;
        put "输出文件: " outpath;

        readpath=filepath;
        file outref filevar=outpath;
        infile inref filevar=readpath end=eof truncover;
        do until(eof);
            input line $char32767.;

            if all_output then put line;
            else do;
                if find(upcase(line), upcase("&start_marker.")) then started=1;
                else if find(upcase(line), upcase("&end_marker.")) then started=0;
                else if started=1 then put line;
            end;
        end;
    run;

    /* ------------------------输出转换情况汇总------------------------ */
    %put NOTE: 已完成SAS文件转换为TXT文件，按照截取标识，文件转换情况如下：;

    options nonotes;
    data _null_;
        set _Temp_tol_markers;
        length basename $512;
        basename = substr(filename, 1, lengthn(filename)-4);

        if has_start_markers=1 and has_end_markers=1 then
            put "Note: " basename "按开始截取标识和截取结束标识完成转换。";
        else if has_start_markers=0 and has_end_markers=1 then
            put "WARNING: " basename "未找到开始截断标识，从文件开始已转换至截取结束标识处。";
        else if has_start_markers=1 and has_end_markers=0 then
            put "WARNING: " basename "找到开始截断标识但未找到结束标识，从开始标识处已转换至文件末尾。";
        else if has_start_markers=0 and has_end_markers=0 then
            put "WARNING: " basename "未找到任何截取标识，已转换全文。";
    run;

    proc delete data=_Temp_tol_markers _SAS_filelist;
    quit;
    options notes;
%end;

%mend;



/* 测试 */
/*%Transform_SAS_to_TXT(    input_dir = %str(C:\Users\liush\Desktop\项目文件\2024\10 IBA-质子治疗系统（成都）\04 统计分析\11 数据递交文件\03 程序代码\02 TFL),*/
/*							output_dir = %str(C:\Users\liush\Desktop\项目文件\2024\10 IBA-质子治疗系统（成都）\04 统计分析\11 数据递交文件\03 程序代码\02 TFL),*/
/*							full_text_yn = 0 ,*/
/*							start_marker = %str(SUBMIT BEGIN),*/
/*							end_marker   = %str(SUBMIT END)*/
/*);*/

