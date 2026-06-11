%option noyywrap yylineno

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"
%}

DIGIT		[0-9]
LETTER		[a-zA-Z]
ID_REGEX	({LETTER}|_)({LETTER}|{DIGIT}|_)*

%%

[ \t\n]+	{}
"--".*		{}
"/*"([^*]|\*+[^*/])*\*+"/" {}


(?i:select)	{ return SELECT; }
(?i:from)	{ return FROM; }
(?i:where)	{ return WHERE; }
(?i:create)	{ return CREATE; }
(?i:table)	{ return TABLE; }
(?i:int)	{ return INT; }
(?i:varchar)	{ return VARCHAR; }
(?i:float)	{ return FLOAT; }
(?i:group)	{ return GROUP; }
(?i:order)	{ return ORDER; }
(?i:by)		{ return BY; }
(?i:and)	{ return AND; }
(?i:or)		{ return OR; }
(?i:not)	{ return NOT; }
(?i:limit)	{ return LIMIT; }
(?i:in)		{ return IN; }
(?i:join)	{ return JOIN; }
(?i:on)		{ return ON; }
(?i:as)		{ return AS; }
"."		    { return '.'; }
"!="		{ return NEQ; }
"<="		{ return LTE; }
">="		{ return GTE; }
";"		{ return ';'; }
","		{ return ','; }
"("		{ return '('; }
")"		{ return ')'; }
"="		{ return '='; }
"<"		{ return '<'; }
">"		{ return '>'; }
"*"		{ return '*'; }


{ID_REGEX}	{ 
		    yylval.str_val = strdup(yytext); 
		    return ID; 
		}
                    
-[1-9]{DIGIT}*|0        { 
                            yylval.int_val = atoi(yytext); 
                            return INT_LIT; 
                        }
[1-9]{DIGIT}*           { 
                            yylval.int_val = atoi(yytext); 
                            return POS_INT; 
                        }
-?{DIGIT}+"."{DIGIT}+   { 
                            yylval.float_val = atof(yytext);
                            return FLOAT_LIT; 
                        }
'[^']*'                 { 
                            yylval.str_val = strdup(yytext);
                            return STRING_LIT; 
                        }

.		{ printf("error: Unrecognized character %s\n", yytext); }

%%


