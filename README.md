# MD5PaswordCracker
Given a text file of passwords and choices for each possible character in the password, it will use multiple threads on the cpu and gpu to brute force all possible choices. On my 2015 MacBook Pro it saw 4.5x performance increase with using the gpu and multiple threads on the cpu.

# Steps
1) Change url at line 390. First line in func main or search for CHANGE 1 URL. Change it to your list of md5 encrypted passwords. Make sure each line in the file is only a single password.
2) Change endBatch at line 419. In func main or search for CHANGE 2 endBatch. Make it be the total possibilities of all characters or total possibilities of character 1 * total possibilities of character 2 ... total possibilities of character n.
3) Change letterChoicesTotalSize at line 420. In func main or search for CHANGE 3 letterChoicesTotalSize. Change to the Sum of possible choices at each character + 1. 
4) Modify 421 - 430 or the next following lines. Each param str should be all the possibilities of the character at the index. 0 index at at the bottom and the last is at the top.
5) Search for CHANGE 5 and look at the code between them. Modify them to say how many threads on CPU and GPU you want running
