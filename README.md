# Macro-for-Transform_SAS_to_TXT-in-SAS
  SAS宏程序  
  批量将`SAS代码文件（后缀为 .sas）`，转换为`TXT格式文件 后缀 .txt`；  
  可用于`临床试验 代码递交 的批量格式转换`。

# 必填参数目录content
- [input_dir](#input_dir)  
- [output_dir](#output_dir)  

# 可选参数目录content
- [full_text_yn](#full_text_yn)  
- [start_marker](#start_marker)  
- [end_marker](#end_marker)  
 

# 宏程序使用语法
```sas
%Transform_SAS_to_TXT( input_dir = %str(), output_dir = %str(), full_text_yn = 0, start_marker = %str(SUBMIT BEGIN), end_marker = %str(SUBMIT END) );
```

# 参数使用语法
## input_dir
  输入需转换的原始SAS代码文件所在文件夹路径（绝对路径或宏参数赋值的相对路径）。

## output_dir
  输出转换后的TXT格式文件存放的文件夹路径（绝对路径或宏参数赋值的相对路径）。

## full_text_yn
  是否需将 原始SAS格式文件全文 转换输出 至TXT格式文件。
  当[full_text_yn](#full_text_yn) = 0时，将通过截取规则（从开始截取至截取结束标识之间的内容）进行部分截取，此时log日志会呈现每一个文件的截取情况。
  log日志会出现的截取情况如下：
  1.`Note: filename 按开始截取标识和截取结束标识完成转换。`
  2.`WARNING: filename 找到开始截断标识但未找到结束标识，从开始标识处已转换至文件末尾。`
  3.`WARNING: filename 未找到任何截取标识，已转换全文。`
  
  <div align="center">

| 可选项（数值型）  |   含义      |
|  ---------        | -------     |
| 0                 | 否  |
| 1                 |  是   |

</div>    

  default  
  ```sas  
  full_text_yn = 0 ;  
  ```  

## start_marker
  开始截取标识`开放文本`（仅[full_text_yn](#full_text_yn) = 0时生效）。
  指定 SAS转换为TXT的首行标识（输出不含首行）。

  default  
  ```sas  
  start_marker = %str(SUBMIT BEGIN) ;  
  ```


## end_marker
  截取结束标识`开放文本`（仅[full_text_yn](#full_text_yn) = 0时生效）。
  指定 SAS转换为TXT的末行标识（输出不含末行）。

  default  
  ```sas  
  end_marker   = %str(SUBMIT END) ;  
  ```
  
  
