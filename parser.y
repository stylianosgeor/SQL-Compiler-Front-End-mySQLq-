%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>

using namespace std;

extern FILE *yyin;
extern int yylex();
extern int yylineno;
void yyerror(const char *s); 


enum DataType { TYPE_INT, TYPE_FLOAT, TYPE_VARCHAR };

struct Column {
    string name;
    DataType type;
};

struct Table {
    string name;
    vector<Column> columns;
};

//stores tables
unordered_map<string, Table> symbol_table;

//stores aliases
unordered_map<string, string> current_query_tables;

struct ParsedColumn { string prefix; string name; int line; };
vector<ParsedColumn> pending_select_cols;
vector<DataType> current_in_list_types;
vector<Column> temp_columns;
DataType current_type;

//error checks

void checkTableExists(string tableName, int line) {
    if (symbol_table.find(tableName) == symbol_table.end()) {
        fprintf(stderr, "\nError (Line %d): Table '%s' does not exist.\n", line, tableName.c_str());
        exit(1);
    }
}

//returns column type if found otherwise exits with error
DataType checkAndGetColumnType(string prefix, string colName, int line) {
    if (prefix != "") {
        //checks if the prefix exists
        if (current_query_tables.find(prefix) == current_query_tables.end()) {
            fprintf(stderr, "\nError (Line %d): Alias or Table '%s' is not declared in FROM/JOIN.\n", line, prefix.c_str());
            exit(1);
        }
        string actual_table = current_query_tables[prefix];
        Table tbl = symbol_table[actual_table];
        for (size_t i = 0; i < tbl.columns.size(); i++) {
            if (tbl.columns[i].name == colName) return tbl.columns[i].type;
        }
        fprintf(stderr, "\nError (Line %d): Column '%s' not found in table/alias '%s'.\n", line, colName.c_str(), prefix.c_str());
        exit(1);
    } else {
        //if prefix not given(student_id instead of s.student_id)
        int match_count = 0;
        DataType found_type = TYPE_INT;
        for (auto const& pair : current_query_tables) {
            //if table has aliases it doesnt allow to be called without prefix
            if (pair.first != pair.second) continue; 

            Table tbl = symbol_table[pair.second];
            for (size_t i = 0; i < tbl.columns.size(); i++) {
                if (tbl.columns[i].name == colName) {
                    match_count++;
                    found_type = tbl.columns[i].type;
                }
            }
        }
        if (match_count == 0) {
            fprintf(stderr, "\nError (Line %d): Column '%s' not found (or you missed its alias prefix).\n", line, colName.c_str());
            exit(1);
        }
        if (match_count > 1) {
            fprintf(stderr, "\nError (Line %d): Column '%s' is ambiguous (exists in multiple tables).\n", line, colName.c_str());
            exit(1);
        }
        return found_type;
    }
}

void checkTypeCompatibility(DataType colType, DataType litType, int line) {
    if (colType == TYPE_INT && litType != TYPE_INT) {
        fprintf(stderr, "\nError (Line %d): Type mismatch. Expected INT.\n", line); exit(1);
    }
    if (colType == TYPE_FLOAT && litType != TYPE_INT && litType != TYPE_FLOAT) {
        fprintf(stderr, "\nError (Line %d): Type mismatch. Expected FLOAT or INT.\n", line); exit(1);
    }
    if (colType == TYPE_VARCHAR && litType != TYPE_VARCHAR) {
        fprintf(stderr, "\nError (Line %d): Type mismatch. Expected VARCHAR (String).\n", line); exit(1);
    }
}

%}

%define parse.error verbose

%union {
    int int_val;
    float float_val;
    char *str_val;
    int type_val; 
}

%token <str_val> ID STRING_LIT
%token <int_val> INT_LIT POS_INT
%token <float_val> FLOAT_LIT

%type <type_val> literal column_ref

%token SELECT FROM WHERE GROUP ORDER BY LIMIT CREATE TABLE IN
%token INT FLOAT VARCHAR
%token NEQ LTE GTE
%token JOIN ON AS

%left OR
%left AND
%right NOT
%nonassoc '=' NEQ '<' '>' LTE GTE

%%

program : statement | program statement ;
	
statement : create_table_stmt | select_stmt ;
	
create_table_stmt : CREATE TABLE ID '(' column_list ')' ';' 
	{
		string table_name = $3;
		if (symbol_table.find(table_name) != symbol_table.end()) {
			fprintf(stderr, "\nError (Line %d): Table '%s' already exists.\n", yylineno, table_name.c_str()); exit(1);
		}
		Table new_table; new_table.name = table_name; new_table.columns = temp_columns;
		symbol_table[table_name] = new_table; temp_columns.clear();
	}
	;
	
column_list : column_def | column_list ',' column_def ;
	
column_def : ID column_def_type 
	{
		string col_name = $1;
		for (size_t i = 0; i < temp_columns.size(); i++) {
			if (temp_columns[i].name == col_name) {
				fprintf(stderr, "\nError (Line %d): Column '%s' already exists.\n", yylineno, col_name.c_str()); exit(1);
			}
		}
		Column new_col = {col_name, current_type}; temp_columns.push_back(new_col);
	}
	;
	
column_def_type : INT { current_type = TYPE_INT; }
	| FLOAT { current_type = TYPE_FLOAT; }
	| VARCHAR '(' POS_INT ')' { current_type = TYPE_VARCHAR; }
	;

//SELECT STATEMENT(JOIN,Aliases)
select_stmt : SELECT select_column_list from_clause join_list 
	{
		//checks rows selected in SELECT and their types after we know the tables involved(after FROM/JOIN)
		for (size_t i = 0; i < pending_select_cols.size(); i++) {
			checkAndGetColumnType(pending_select_cols[i].prefix, pending_select_cols[i].name, pending_select_cols[i].line);
		}
		pending_select_cols.clear();
	}
	select_stmt_where select_stmt_group select_stmt_order select_stmt_limit ';' 
	{
		current_query_tables.clear(); //end of query clears aliases
	}
	;

from_clause : FROM ID 
	{
		checkTableExists($2, yylineno);
		current_query_tables[$2] = $2; 
	}
	| FROM ID AS ID 
	{
		checkTableExists($2, yylineno);
		current_query_tables[$4] = $2; //stores aliases in current_query_tables
	}
	;

join_list : | join_list join_item ;

join_item : JOIN ID 
	{
		checkTableExists($2, yylineno); current_query_tables[$2] = $2;
	} ON column_ref '=' column_ref
	| JOIN ID AS ID 
	{
		checkTableExists($2, yylineno); current_query_tables[$4] = $2;
	} ON column_ref '=' column_ref
	;

select_stmt_where : WHERE condition | ; //empty
select_stmt_group : GROUP BY column_ref_list | ;//empty
select_stmt_order : ORDER BY column_ref_list | ;//empty
select_stmt_limit : LIMIT POS_INT | ;//empty

//column management
select_column_list : '*' | pending_col_list ;

pending_col_list : pending_col | pending_col_list ',' pending_col ;

//stores rows temporarily until we know the tables involved(after FROM/JOIN) to check their validity and types
pending_col : ID 
	{ pending_select_cols.push_back({"", $1, yylineno}); }
	| ID '.' ID 
	{ pending_select_cols.push_back({$1, $3, yylineno}); }
	;

column_ref_list : column_ref | column_ref_list ',' column_ref ;

//checks and returns column type if found otherwise error
column_ref : ID 
	{ $$ = checkAndGetColumnType("", $1, yylineno); }
	| ID '.' ID 
	{ $$ = checkAndGetColumnType($1, $3, yylineno); }
	;

condition : expression 
	| condition AND condition 
	| condition OR condition 
	| NOT condition
	;
	
expression : column_ref oper literal 
	{ checkTypeCompatibility((DataType)$1, (DataType)$3, yylineno); }
	| column_ref IN '(' literal_list ')'
	{
		for(size_t i=0; i<current_in_list_types.size(); i++) {
			checkTypeCompatibility((DataType)$1, current_in_list_types[i], yylineno);
		}
		current_in_list_types.clear();
	}
	| column_ref NOT IN '(' literal_list ')' 
	{
		for(size_t i=0; i<current_in_list_types.size(); i++) {
			checkTypeCompatibility((DataType)$1, current_in_list_types[i], yylineno);
		}
		current_in_list_types.clear();
	}
	;
	
oper : '=' | NEQ | '<' | '>' | GTE | LTE ;
	
literal_list : literal { current_in_list_types.push_back((DataType)$1); }
	| literal_list ',' literal { current_in_list_types.push_back((DataType)$3); }
	;
	
literal : INT_LIT { $$ = TYPE_INT; }
	| POS_INT { $$ = TYPE_INT; }
	| FLOAT_LIT { $$ = TYPE_FLOAT; }
	| STRING_LIT { $$ = TYPE_VARCHAR; }
	;
	
%%

void yyerror(const char *s){
	fprintf(stderr, "Syntax Error at line %d: %s\n", yylineno, s);
}

int main(int argc, char **argv){
	if (argc != 2) {
		fprintf(stderr, "Usage: %s <file_name>\n", argv[0]); return 1;
	}
	FILE *file = fopen(argv[1], "r");
	if (!file) { perror("Error opening file"); return 1; }
	
	printf("---- Source Program ----\n");
	char c; while ((c = fgetc(file)) != EOF) { putchar(c); }
	printf("\n----------------------\n");
	
	rewind(file); yyin = file;
	int result = yyparse();
	
	if (result == 0) printf("Parsing completed successfully. No syntax or semantic errors were detected\n");
	fclose(file); return result;
}