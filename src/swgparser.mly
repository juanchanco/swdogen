%{
open Ast 

let makeTokenData () =
  let pos = symbol_start_pos ()
  in
      (TokenData(pos.Lexing.pos_fname, pos.Lexing.pos_lnum, (pos.Lexing.pos_cnum - pos.Lexing.pos_bol)))
%}

%token EOF

%token <int>    T_INT_LITERAL
%token <float>  T_FLOAT_LITERAL
%token <string> T_IDENTIFIER
%token <string> T_STRING_LITERAL
%token <string> T_URL

/* ( ) [ ] , - | ' '' : ? = */
%token T_LPAREN T_RPAREN T_LBRACE T_RBRACE T_COMMA T_MINUS T_VBAR T_DQUOTE T_QUOTE T_COLON T_QMARK T_ASG

/* predefined type */
%token T_INT T_LONG T_FLOAT T_DOUBLE
%token T_STRING T_BYTE T_BOOLEAN
%token T_DATE T_DATETIME
%token T_ARRAY T_SET
%token T_OPTION T_VOID

/* parameter type */
%token T_PARAM_PATH T_PARAM_BODY T_PARAM_QUERY T_PARAM_HEADER T_PARAM_FORM

/* http method */
%token T_METHOD_GET T_METHOD_POST T_METHOD_PUT T_METHOD_DELETE T_METHOD_HEAD

/* swg doc definition */
/* TODO: namespace
%token T_AT_NAMESPACE
*/
%token T_AT_RESOURCE T_AT_DESC T_AT_APINAME T_AT_BASEPATH
%token T_AT_URL T_AT_SUMMARY T_AT_RETURN T_AT_RESPONSE T_AT_NOTES T_AT_METHOD
%token T_AT_PARAM
%token T_AT_MODEL T_AT_PROPERTY

%start single_swg_source_file              /* the entry point */
%type <Ast.sourceFile> single_swg_source_file

%%
constant_literal:
    num_literal      { NumLiteral ($1) }
  | T_STRING_LITERAL { String (makeTokenData(), $1) }
;
desc:
  T_STRING_LITERAL   { Desc (makeTokenData(), $1) }
;
url:
  T_URL              { URL (makeTokenData(), $1) }
;
identifier:
  T_IDENTIFIER       { Identifier (makeTokenData(), $1) }
;
num_literal:
  | T_INT_LITERAL    { Int   (makeTokenData(), $1) }
  | T_FLOAT_LITERAL  { Float (makeTokenData(), $1) }
;
rangable_type:
    T_INT            { T_INT    (makeTokenData()) }
  | T_LONG           { T_LONG   (makeTokenData()) } 
  | T_FLOAT          { T_FLOAT  (makeTokenData()) }
  | T_DOUBLE         { T_DOUBLE (makeTokenData()) }
;
primitive_type:
    rangable_type    { RangableType ($1) }
  | T_STRING         { T_STRING     (makeTokenData()) }
  | T_BYTE           { T_BYTE       (makeTokenData()) }
  | T_BOOLEAN        { T_BOOLEAN    (makeTokenData()) }
  | T_DATE           { T_DATE       (makeTokenData()) }
  | T_DATETIME       { T_DATETIME   (makeTokenData()) }
  | T_VOID           { T_VOID       (makeTokenData()) }
;
range_type:
  rangable_type T_LBRACE num_literal T_MINUS num_literal T_RBRACE { RangeType (makeTokenData(), $1, $3, $5) }
;
enum_type_list_postfix:
  /* empty */                                         { [] }
  | T_VBAR constant_literal enum_type_list_postfix    { $2::$3 }
;
enum_type_list:
  constant_literal enum_type_list_postfix             { $1::$2 }
;
enum_type:
  primitive_type T_LPAREN enum_type_list T_RPAREN     { EnumType (makeTokenData(), $1, $3) }
;
compound_type:      
    range_type          { $1 }
  | enum_type           { $1 }
;
argument:
    T_QMARK identifier T_ASG swg_type    { VarDef (makeTokenData(), $2, $4, Optional) }
  | identifier T_ASG swg_type            { VarDef (makeTokenData(), $1, $3, Required) }
;
/* var_def, var_def, ... var_def */
argument_list_postfix:
  /* empty */                              { [] }
  | T_COMMA argument argument_list_postfix { $2::$3 }
;  
argument_list:
    argument argument_list_postfix         { $1::$2 }
;
model_ref:
    identifier T_LPAREN T_RPAREN                { (makeTokenData(), $1, []) }
  | identifier T_LPAREN argument_list T_RPAREN  { (makeTokenData(), $1, $3) }
  | identifier                                  { (makeTokenData(), $1, []) }
;
model_type:
  model_ref                                     { ModelRef ($1) }
;
array_type:
    T_ARRAY T_LBRACE swg_type T_RBRACE  { SWGArray (makeTokenData(), $3) } 
  | T_SET   T_LBRACE swg_type T_RBRACE  { SWGSet   (makeTokenData(), $3) }
;
swg_type:
    model_type           { ModelType     ($1) }
  | compound_type        { CompoundType  ($1) }
  | primitive_type       { PrimitiveType ($1) }
  | array_type           { ArrayType     ($1) }  
;
var_def:
    identifier T_COLON swg_type T_OPTION { VarDef (makeTokenData(), $1, $3, Optional) }
  | identifier T_COLON swg_type          { VarDef (makeTokenData(), $1, $3, Required) }
;
param_type:
    T_PARAM_FORM         { FORM   (makeTokenData()) }
  | T_PARAM_HEADER       { HEADER (makeTokenData()) }
  | T_PARAM_QUERY        { QUERY  (makeTokenData()) }
  | T_PARAM_BODY         { BODY   (makeTokenData()) }
  | T_PARAM_PATH         { PATH   (makeTokenData()) }
;
http_method:
    T_METHOD_GET         { GET    (makeTokenData()) }
  | T_METHOD_POST        { POST   (makeTokenData()) }
  | T_METHOD_PUT         { PUT    (makeTokenData()) }
  | T_METHOD_DELETE      { DELETE (makeTokenData()) }
  | T_METHOD_HEAD        { HEAD   (makeTokenData()) }
;
staus_code:
  T_INT_LITERAL          { StatusCode (makeTokenData(), $1) }
;
operation_property:
    T_AT_METHOD  http_method                                     { (Method      (makeTokenData(), $2)) }
  | T_AT_RETURN  swg_type                                        { (Return      (makeTokenData(), $2)) }
  | T_AT_SUMMARY desc                                            { (Summary     (makeTokenData(), $2)) }
  | T_AT_NOTES   desc                                            { (Notes       (makeTokenData(), $2)) }
  | T_AT_RESPONSE  staus_code  desc                              { (ResponseMsg (makeTokenData(), $2, None, $3)) }
  | T_AT_RESPONSE  staus_code  model_ref  desc                   { (ResponseMsg (makeTokenData(), $2, (Some $3), $4)) }
  | T_AT_PARAM   var_def     param_type desc                     { (ParamDef    (makeTokenData(), $2, $3, $4)) }
;
operation_property_list:
  /* empty */                                                    { [] }
  | operation_property operation_property_list                   { $1::$2 }
;
operation_def:
  T_AT_APINAME identifier operation_property_list                { (OperationDef (makeTokenData(), $2, $3)) }
;
operation_def_list:
  /* empty */                                                    { [] }
  | operation_def operation_def_list                             { $1::$2 }
;
api_def:
  T_AT_URL url operation_def_list                                { (APIDef (makeTokenData(), $2, $3)) }
; 
api_def_list:
  /* empty */                                                    { [] }
  | api_def api_def_list                                         { $1::$2 }
;
property_def_list:
  /* empty */                                                    { [] }
  | T_AT_PROPERTY var_def desc property_def_list                 { (PropertyDef (makeTokenData(), $2, $3))::$4 }
;
model_def:
  T_AT_MODEL identifier property_def_list { (makeTokenData(), $2, $3) }
;
tail_model_def_list:
  /*empty*/                               { [] }
  | model_def tail_model_def_list         { $1::$2 }
;
model_def_list:
  model_def tail_model_def_list           { $1::$2 }
;
base_path:
  T_AT_BASEPATH url                       { (BasePath (makeTokenData(), $2)) }
;
resource_def:
   T_AT_RESOURCE url desc base_path api_def_list      { (ResourceDef (makeTokenData(), $2, $3, $4, $5)) }
; 
tail_resource_def_list:
  /* empty */                             { [] }
  | resource_def tail_resource_def_list   { $1::$2 }
;
resource_def_list:
  resource_def tail_resource_def_list     { $1::$2 }
;
/**************************
 * single SWG source file
 **************************/
swg_doc_item_list:
  /* empty */                             { [] }
  | resource_def_list swg_doc_item_list   { (ResourceDefs ($1)) :: $2 }
  | model_def_list    swg_doc_item_list   { (ModelDefs    ($1)) :: $2 }
;
single_swg_source_file:
    swg_doc_item_list EOF                 { SWGSourceFile($1) }
  | EOF                                   { raise Invalid_ast }
;