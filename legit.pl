#!/usr/bin/perl -w
#TODO
#Cases for commands withour init
#Folders being commited

use strict;
use Cwd;
use File::Basename;
use File::Compare;
use Data::Dumper;
use File::Copy;
#INIT
sub legit_init(){
    my $curr_dir = getcwd();
    if( -e "$curr_dir/.legit"){
        print "legit.pl: error: .legit already exists\n";
    }else{
        mkdir "$curr_dir/.legit";
        mkdir "$curr_dir/.legit/index";
        print "Initialized empty legit repository in .legit\n";
    }
}

#ADD [filenames]
sub legit_add(){
    shift @ARGV; #remove the add command
    my $curr_dir = getcwd();
    my $legit_path = "$curr_dir/.legit";
    if (is_dir_empty($legit_path) == -1){
        print "legit.pl: error: no .legit directory containing legit repository exists\n";
        return;
    }
    
    foreach my $file (@ARGV){
        #print "File = $file\n";
        if ( (!-e $file) ){ 
            #file does not exist
            print "legit.pl: error: can not open '$file'\n";
        }elsif( -f $file ){
            #print "plain file\n";
            my $first_char = substr($file, 0, 1);
            #print $first_char."\n";
            if(($first_char =~ /^[A-Za-z0-9]/ ) and ($file =~ /^[-\w\.]+$/)){
                #print "ValidName\n";
                #Copy this file into index
                open FILE_R, '<', "$curr_dir/$file", or die "Cant open read file";
                open FILE_W, '>', ".legit/index/$file" or die "Cant open write file";
                foreach my $line (<FILE_R>){
                    print FILE_W $line;
                }
                #print"Added\n";
                close(FILE_R);
                close(FILE_W);
            }else{
                print "legit.pl: error: invalid filename '$file'\n";
            }
        }else{
            print "legit.pl: error: '$file is not a regular file\n";
        }
    }
}

#To check if a directory is empty or not
#Returns -1 if directory does not exist, -2 if it is not a directory, 0 if not empty, 1 if empty
sub is_dir_empty {
    return -1 if not -e $_[0];   # does not exist
    return -2 if not -d $_[0];   # in not a directory
    opendir my $dir, $_[0] or    # likely a permissions issue
        die "Can't opendir '".$_[0]."', because: $!\n";
    readdir $dir; #for a . file
    readdir $dir; #for a .. file
    return 0 if ( readdir $dir ); #if any file exists
    return 1;
}

#Returns 0 if commit not required, else returns 1 
sub is_commit_required(){
    OUTER:
    foreach my $file (glob ".legit/index/*"){
        #Populating num array with commit numbers of file in descending order
        my @num_arr; #declared but undefined
        foreach my $file (glob ".legit/commit_?"){
            #print "$file\n";
            $file =~ /commit_([0-9]+)/;
            my $commit_num = $1;
            push @num_arr, $commit_num;
        }  
        @num_arr = sort {($b) <=> ($a)} @num_arr;
        #print @num_arr;

        if(scalar(@num_arr) == 0){
            return 1;
        }
        #multiple file cases problem
        while (@num_arr){
            my $n = shift @num_arr;
            my $file_found = 0;
            #print "File found : $file_found\n";
            foreach my $commit_file (glob ".legit/commit_$n/*"){
                #print "Commit file = $commit_file\n";
                #print "File = $file\n";
                if(basename($commit_file) eq basename($file)){
                    $file_found = 1;
                    #print "Basename matches\n";
                    if(compare($file, $commit_file) != 0){
                        #print "Found not equal!\n";
                        #print "Found not equal Commit file = $commit_file\n";
                        #print "Found not equal File = $file\n";
                        return 1;
                    }else{
                        last OUTER;
                    }
                }
            }
            if($file_found == 0 and $n == 0){
                #print "new file\n";
                return 1;
            }    
    
        }
    }
    return 0;
}
            
                
                    
                    
    
#COMMIT
sub legit_commit_M(){
    my $arg_m;
    my $commit_message;
    if ($arg_m = shift @ARGV) {
        if(!($arg_m =~ /^-m$/) or (!($commit_message = shift @ARGV)) ){
            print "usage: legit.pl commit [-a] -m commit-message\n";
        }else{
            #checking if file in index is the same as last commited version
           
            my $flag = 0;
            my $commit_dir; 
            my $commit_num = 0;
            my $check_dir = is_dir_empty(".legit/index");
            
            if ($check_dir == 1){
                print "nothing to commit\n";
            }else{
                if(is_commit_required() == 0){
                    print "nothing to commit\n";
                    foreach my $file (glob ".legit/index/*"){
                        unlink $file;
                    }
                    return;
                }

                while ($flag == 0){
                    $commit_dir = ".legit/commit_$commit_num";
                    #print "Commit dir : $commit_dir\n";
                    if ( -e $commit_dir and -d $commit_dir){
                        $commit_num++;
                        $commit_dir = ".legit/commit_$commit_num";
                        #print "Increasing commit count\n";
                    }else{
                        $flag = 1;
                        
                        mkdir $commit_dir;
                        #print "Making dir $commit_dir\n";
                        my $curr_dir = getcwd();
                        #print $curr_dir."\n";
                        foreach my $read_file (glob ".legit/index/*"){
                            #print "$read_file\n";
                            my $base_name = basename($read_file);
                            #print "base name = $base_name\n";
                            open FILE_R, '<', "$read_file", or die "Cant open read file";
                    
                            my $write_file = "$curr_dir/$commit_dir/$base_name";
                            #print "Write file= $write_file";
                            open FILE_W, '>', "$write_file" or die "Can't open write file";
                            foreach my $line (<FILE_R>){
                                print FILE_W $line;
                            }
                            close(FILE_R);
                            close(FILE_W);
                            unlink $read_file;

                            open F_W, '>', "$curr_dir/$commit_dir/msg.txt" or die "Couldnt open message file\n";
                            print F_W $commit_message;
                        }
                        print "Committed as commit $commit_num\n";
                        
                    }
                }      
            }    
        }
    }else{
        print "usage: legit.pl commit [-a] -m commit-message\n";
    }
}

#Parameters : file name
#Returns the latest commited version of given file
sub getLatestCommitedVersion{
    #go through all files in commits reverse order and compare to received_file
    #if find received file return
    #else return NULL
    my ($file_received) = @_;
    my @num_arr; 
    foreach my $file (glob ".legit/commit_?"){
        $file =~ /commit_([0-9]+)/;
        my $commit_num = $1;
        push @num_arr, $commit_num;
    }  
    @num_arr = sort {($b) <=> ($a)} @num_arr;

    my $file_found = 0;
    while (@num_arr){
        my $n = shift @num_arr;
        foreach my $commits_file (glob ".legit/commit_$n/*"){
            #print "Commits file = $commits_file\n";
            #print "File received = $file_received\n";
            if(basename($commits_file) eq basename($file_received)){
                print "File Found!\n";
                $file_found = 1;
                return $commits_file;
                last;
            }
        }
    }
    
    if($file_found == 0){
        #print "File not found in any commit folder\n";
        return -1;
    }
}


sub legit_commit_A(){
    my $arg_a;
    my $arg_m;
    my $commit_message;
    if ($arg_a = $ARGV[0] and $arg_m = $ARGV[1]) {
        if(!($arg_a =~ /^-a$/) or (!($arg_m =~ /^-m$/)) or (!($commit_message = $ARGV[2])) ){
            print "usage: legit.pl commit [-a] -m commit-message\n";
        }else{
            my $curr_dir = getcwd();
            foreach my $cwd_file (glob "$curr_dir/*"){
                #print "Curr dir = $cwd_file\n";
                my $is_copied = 0;
                foreach my $index_file (glob ".legit/index/*"){
                    #print "Curr index file = $index_file\n";
                    if(basename($index_file) eq basename($cwd_file) and compare($index_file,$cwd_file) != 0){
                        #print "Copying\n";
                        unlink $index_file;
                        $is_copied = 1;
                        copy($cwd_file, $index_file) or die "Couldn't copy\n";
                        next;
                    }
                }
                if($is_copied == 0){
                    my $latestCommit_file  = getLatestCommitedVersion($cwd_file);
                    #print "Latest Commit file = $latestCommit_file\n";
                    if($latestCommit_file ne -1){
                        if(compare($latestCommit_file, $cwd_file) != 0){
                            #print "Latest commit file not equal to cwd file\n";
                            copy($cwd_file, ".legit/index");
                        }
                    }
                }
            }
            #removing the -m
            shift @ARGV;
            legit_commit_M();
        }
    }
}

#LOG
sub legit_log(){
    my %num_msg; #declared but undefined
    foreach my $file (glob ".legit/commit_?/msg.txt"){
        #print "$file\n";
        $file =~ /commit_([0-9]+)/;
        my $commit_num = $1;
        open F , '<', $file or die "Can't open commit message file\n";
        my $commit_msg = <F>;
        $num_msg{$commit_num} = $commit_msg;
    }  
    if(%num_msg){
        foreach my $i (reverse sort keys %num_msg){
            print "$i $num_msg{$i}\n";
        }
    }else{
        print "legit.pl: error: your repository does not have any commits yet\n";
    }
}


#TBD what happens if commit number is not a number??
sub legit_show(){
    shift @ARGV; #remove the show
    my @vals = split /:/, $ARGV[0];
    my $commit_num = $vals[0];
    my $file = $vals[1];
    if ($commit_num =~ /[0-9]+/){
        #print "All okay\n";
    }else{
        $commit_num = -1;
        #print "Commit num val is -1\n";
    }
    
    #Checking if the repository has any commits yet
    my $file_checker = ".legit/commit_0";
    print "legit.pl: error: your repository does not have any commits yet\n" if ( !(-e $file_checker));

    #If file does not exist anyhwere
    #if (!(-e $file)){
        #print "legit.pl: error: invalid filename '$file'\n";
    if($commit_num == -1){
        #commit number not specified
        #print contents of file from index. If index is empty print file contents from last commit it was in
        my $is_empty = is_dir_empty(".legit/index");
        if ($is_empty){
            #print "Index directory is empty\n";
            
            my @num_arr; #declared but undefined
            foreach my $file (glob ".legit/commit_?"){
            #print "$file\n";
                $file =~ /commit_([0-9]+)/;
                my $commit_num = $1;
                push @num_arr, $commit_num;
            }  
            @num_arr = sort {($b) <=> ($a)} @num_arr;
            my $found = 0;
            while (@num_arr and $found == 0){
                my $n = shift @num_arr;
                foreach (glob ".legit/commit_$n/*"){
                    if($file eq  basename($_)){
                        #print "Found!! $_\n";
                        $found = 1;
                        open F, '<', $_ or die "Can't open read file\n";
                        foreach (<F>){
                            print "$_";
                        }
                    }   
                }
            }

            if($found == 0){
                print "legit.pl: error: '$file' not found in index\n";
            }  
        }else{
            #print "Directory not empty\n";
            foreach my $read_file (glob ".legit/index/*"){
                if(basename($read_file) eq $file){
                    open F, '<', $read_file or die "Can't open read file\n";
                    foreach (<F>){
                        print "$_";
                    }
                }
            }
        } 
    }else{ 
        #commit number is specified
        #loop through all files in that commit and find $file
        #display contents of file
        #If file not found in that commit print the last commit it was in
        #print "In else commit num : $commit_num\n";
        #print "In else File name : $file\n";
        my $f = ".legit/commit_$commit_num";
        #print $f."\n";
        my $found = 0;
        if(is_dir_empty("$f") == -1){
            print "legit.pl: error: unknown commit '$commit_num'\n";
        }else{
            foreach my $read_file (glob "$f/*"){
                #print "In for\n";
                #print "Read file : $read_file\n";
                if ($found != 1){
                    if ($file eq basename($read_file)){
                        open FILE_R, '<', $read_file or die "Cannot open read file\n";
                        foreach (<FILE_R>){
                            $found = 1;
                            print "$_";
                        }
                    }
                }
            }
            my $i = 0;
            if($found == 0){
                foreach my $read_file (glob ".legit/commit_$i/*"){
                    #print "File reading = $read_file\n";
                    #print "File = $file\n";
                    #print basename($read_file)."\n";
                    if ($file eq basename($read_file)){
                        #print "In in\n";
                        open FILE_R, '<', $read_file or die "Cannot open read file\n";
                        foreach (<FILE_R>){
                            $found = 1;
                            print "$_";
                        }
                    }else{
                        #print "In else\n";
                        $i++;
                        #print "i = $i\n";
                    }
                    #print "Commit num = $commit_num\n";
                    last if ($i > $commit_num);
                }  
            }
            print "legit.pl: error: '$file' not found in commit $commit_num\n" if ($found == 0);
        }
    }
    #print $file;
}





#TBD unknown command error message to be printed for all commands if spelled wrong
if ($ARGV[0] eq "init"){
    legit_init();
}elsif($ARGV[0] eq "add"){
    legit_add();
}elsif($ARGV[0] eq "commit"){
    shift @ARGV; #removing the commit arg
    my $arg = $ARGV[0];
    #print "Arg = $arg";
    if($arg =~ /^-m$/){
        legit_commit_M();
    }else{
        legit_commit_A();
    }
}elsif($ARGV[0] eq "log"){
    legit_log();
}elsif($ARGV[0] eq "show"){
    legit_show();
}
