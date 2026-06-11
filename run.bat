@echo off
echo [1] Running Bison...
bison -d parser.y

echo [2] Running Flex...
flex lexer.l

echo [3] Compiling with g++...
g++ lex.yy.c parser.tab.c -o myParser.exe

echo [4] Running the program...
echo ========================================
myParser.exe testfinal.sql
echo ========================================