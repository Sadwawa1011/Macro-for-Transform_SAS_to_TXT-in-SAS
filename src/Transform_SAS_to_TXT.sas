
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
		start_marker 	:  开始截取的标识符号，默认为“SUBMIT BEGIN”，当 Must_marker_yn=1 时生效
		end_marker   	:  截取结束的标识符号，默认为“SUBMIT END”，当 Must_marker_yn=1 时生效
*/



/* ------------------确保输入SAS文件所在目录，转换后TXT文件输出目录存在----------------- */
data _null_;
    inpath = "&input_dir.";
	outpath = "&output_dir.";
	if fileexist(inpath) then do;
        put "NOTE: 输出目录存在: " inpath;
		call symputx('input_exists', '1');
	end;
    else do;
        put "WARNING: 输入的SAS文件所在目录不存在 -> " inpath;
        put "WARNING: 请确保该目录已手动创建，否则程序将无法读取SAS文件。";
		call symputx('input_exists', '0');
    end;
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


/* ------------------如果任一目录不存在，则终止宏，不执行后续转换-------------------- */
%if &input_exists = 0 or &output_exists = 0 %then %do;
    %put ERROR: 由于目录不存在，宏将退出，不执行批量转换。;
    %return;
%end;



/* -------------------------------------批量处理------------------------------------ */
/* 不考虑截断标识，原文件全文输出 */
%if &full_text_yn = 1 %then %do;
	data _null_;
	    length filepath $1000 outpath $1000 line $32767;
	    /* 获取所有.sas文件列表 */
	    infile "&input_dir.\*.sas" filename=filepath eof=done truncover;
	    input line $32767.;
	    /* 检测文件切换 */
	    if _n_ = 1 or filepath ne lag(filepath) then do;
	        /* 构建输出文件路径 */
	        filename = scan(filepath, -2, '.\');
	        outpath = cats("&output_dir.\", filename, '.txt');
	        put "处理文件: " filepath;
	    end;
	    /* 使用FILE语句，通过FILEVAR动态指定输出文件 */
	    file dummy filevar=outpath;
	    /* 全文逐行输出 */
	    put line;
	    return;
	    done:stop;
	run;
	%put note: 所有文件均按照原SAS文件全文转换为TXT文件. ;
%end;
/* ----------------------------------根据 截断标识 输出------------------------------- */
%else %if &full_text_yn = 0 %then %do;
	/* 扫描两遍，第一遍确认是否有开始标识，第二遍开始逐行输出 */
	/* 第一步：预扫描所有文件，找出哪些文件包含标识符 */
	data _Temp_tol_markers;
	    length filepath $1000 line $32767;
		/* 依次为：是否有开始标识、是否有结束标识、文件的读取序号（用于hash连接第二步处理） */    
	    retain has_start_markers 0 has_end_markers 0 fileid 0;
	    infile "&input_dir.\*.sas" filename=filepath truncover pad end=eof;
		tem_filename=filepath;
	    input line $32767.;
	    /* 文件切换时增加序号 */
	    if _n_ = 1 or filepath ne lag(filepath) then do;
	        if _n_ > 1 then do;
	            /* 输出上一个文件的结果 */
	            output;
	        end;
			/* 序号递增 */
	        fileid + 1; has_start_markers = 0; has_end_markers = 0;
	    end;
	    /* 检查标记 */
	    if find(upcase(line), upcase("&start_marker.")) then 
	        has_start_markers = 1;
		if find(upcase(line), upcase("&end_marker.")) then 
	        has_end_markers = 1;
		/* 最后一个文件进行输出 */
	    if eof then output;        
	    keep tem_filename fileid has_start_markers has_end_markers;
	run;


	/* ---------------------第二步：data步迭代输出所需的每一行------------------- */
	data _null_;
	    length filepath $1000 outpath $1000 line $32767;
		/* 依次为：是否检测到开始标识，是否全文件输出，文件读取序号 */
	    retain started 0 all_output 0 fileid 0;
	    /* 加载第一步的标记表，hash连接，Key 使用 fileid */
	    if _n_ = 1 then do;
	        declare hash h(dataset:"_Temp_tol_markers");
	        h.definekey("fileid");
	        h.definedata("has_start_markers");
	        h.definedone();
	        call missing(fileid, has_start_markers);
	    end;
	    infile "&input_dir.\*.sas" filename=filepath eof=done truncover;
	    input line $32767.;
	    /* 文件切换时：更新序号，并查询标记 */
	    if _n_ = 1 or filepath ne lag(filepath) then do;
	        fileid + 1;             /* 序号与第一步严格一致 */
	        filename = scan(filepath, -2, '.\');
	        outpath = cats("&output_dir.\", filename, '.txt');
	        started = 0;
	        put "处理文件: " filepath;

	        rc = h.find(key:fileid);
	        if rc = 0 and has_start_markers = 1 then 
	            all_output = 0;    /* 有标记 → 截取输出 */
	        else 
	            all_output = 1;    /* 无标记 → 全输出 */
	    end;
	    /* 输出 */
	    file dummy filevar=outpath;
	    if all_output = 1 then 
	        put line;
	    else do;
	        if find(upcase(line), upcase("&start_marker.")) then started = 1;
	        else if find(upcase(line), upcase("&end_marker.")) then started = 0;
	        else if started = 1 then put line;
	    end;
	    return;
	    done: stop;
	run;
	/* ------------------------在Log中输出每个文件的转换情况汇总 ----------------------- */
	%put NOTE: 已完成SAS文件转换为TXT文件，按照截取标识，文件转换情况如下：;
	/* 关闭 SAS 自动 NOTE */
	options nonotes;   
	data _null_;
	    set _Temp_tol_markers end=last;
	    length filename $200;
	    filename = scan(tem_filename, -2, '.\'); /* 提取文件名用于日志显示 */

	    if has_start_markers = 1 and has_end_markers = 1 then do;
	        put "Note: " filename "按开始截取标识和截取结束标识完成转换。";
	    end;
	    else if has_start_markers = 0 and has_end_markers = 1 then do;
	        put "WARNING: " filename "未找到开始截断标识，从文件开始已转换至截取结束标识处。";
	    end;
	    /* 如果有开始标识但没有结束标识，可根据业务需求补充提示 */
	    else if has_start_markers = 1 and has_end_markers = 0 then do;
	        put "WARNING: " filename "找到开始截断标识但未找到结束标识，从开始标识处已转换至文件末尾。";
	    end;
		else if has_start_markers = 0 and has_end_markers = 0 then do;
	        put "WARNING: " filename "未找到任何截取标识，已转换全文。";
	    end;
	run;

	/* 删除过程数据集 */
	proc delete data = _Temp_tol_markers ;
	quit;
	/* 恢复 NOTE 输出 */
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

