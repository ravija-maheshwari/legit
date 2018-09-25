#!/usr/bin/perl -w
#TBD unknown command error message to be printed for all commands if spelled wrong

use strict;
use Cwd;
use File::Basename;
use File::Compare;
use Data::Dumper;
use File::Copy;

#Function to check if a .legit directory exists 
sub is_initialised{
    if(is_dir_empty(".legit") == -1 or is_dir_empty(".legit") == -2){
        #.legit directory does not exist or is not a directory
        return 0;
    }
    return 1;
}

#Function to copy the source file into the destination file
sub copy_files{
    my ($source, $destination) = @_;
    open FILE_R, '<', "$source", or die "Cant open read file";
    open FILE_W, '>', "$destination" or die "Cant open write file";
    foreach my $line (<FILE_R>){
        print FILE_W $line;
    }
    close(FILE_R);
    close(FILE_W);
}

#INIT
#Function to add a .legit directory 
sub legit_init{
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
#Function to stage the provided files in the 'index' directory
sub legit_add{

    #Error prompt if .legit directory does not exist
    if(!(is_initialised)){
        die "legit.pl: error: no .legit directory containing legit repository exists\n";
    }

    shift @ARGV; #removing the add arg 
    my $curr_dir = getcwd();
    my $legit_path = "$curr_dir/.legit";

    foreach my $file (@ARGV){
        if ((! -e $file)){ 
            my $found_in_index = 0;            
            foreach my $f (glob ".legit/index/*"){
                if (basename($f) eq basename($file)){
                    #File to add does not exist in cwd, but exists in index
                    $found_in_index = 1;
                    unlink ".legit/index/$file";
                }
            }
            #File to add does not exist in cwd
            if(!$found_in_index){
                print "legit.pl: error: can not open '$file'\n";
            }
        }elsif( -f $file ){
            #File exists and is a regular file
            my $first_char = substr($file, 0, 1);
            if(($first_char =~ /^[A-Za-z0-9]/ ) and ($file =~ /^[-\w\.]+$/)){
                #Copy file into index
                copy_files("$curr_dir/$file",".legit/index/$file");
            }else{
                print "legit.pl: error: invalid filename '$file'\n";
            }
        }else{
            print "legit.pl: error: '$file' is not a regular file\n";
        }
    }
}

#Function for various checks on a directory
#Returns -1 if directory does not exist, -2 if it is not a directory, 0 if not empty, 1 if empty
sub is_dir_empty {
    return -1 if not -e $_[0];   # does not exist
    return -2 if not -d $_[0];   # in not a directory
    opendir my $dir, $_[0] or   
        die "Can't opendir '".$_[0]."', because: $!\n";
    readdir $dir; #for a . file
    readdir $dir; #for a .. file
    return 0 if ( readdir $dir ); #if any file exists
    return 1;
}

#Function to check if a commit is required based on contents of previous commits
#Returns 0 if commit not required, else returns 1 
sub is_commit_required(){
    OUTER:
    foreach my $file (glob ".legit/index/*"){
        #Populating num array with commit numbers of file in descending order
        my @num_arr; #declared but undefined
        foreach my $file (glob ".legit/commit_?"){
            $file =~ /commit_([0-9]+)/;
            my $commit_num = $1;
            push @num_arr, $commit_num;
        }  
        @num_arr = sort {($b) <=> ($a)} @num_arr;

        #If num_arr is empty, then no commits made yet.
        if(scalar(@num_arr) == 0){
            return 1;
        }

        while (@num_arr){
            my $n = shift @num_arr;
            my $file_found = 0;
            foreach my $commit_file (glob ".legit/commit_$n/*"){
                if(basename($commit_file) eq basename($file)){
                    $file_found = 1;
                    if(compare($file, $commit_file) != 0){
                        #Latest version of files are same, no commit requires
                        return 1;
                    }else{
                        last OUTER;
                    }
                }
            }
            if($file_found == 0 and $n == 0){
                #Reached commit 0 and no file found, commit required
                return 1;
            }    
    
        }
    }
    return 0;
}
            
            
#COMMIT -m "message"
#Function to commit all files in the staging area
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
                    if ( -e $commit_dir and -d $commit_dir){
                        $commit_num++;
                        $commit_dir = ".legit/commit_$commit_num";
                    }else{
                        $flag = 1;       
                        mkdir $commit_dir;
                        my $curr_dir = getcwd();
                        foreach my $read_file (glob ".legit/index/*"){
                            my $base_name = basename($read_file);
                            my $write_file = "$curr_dir/$commit_dir/$base_name";
                            copy_files($read_file,$write_file);
                            unlink $read_file;
                            
                            #Creating a commit message file
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

#Returns the latest commited version number of given file
sub getLatestCommitedVersion{
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
            if(basename($commits_file) eq basename($file_received)){
                print "File Found!\n";
                $file_found = 1;
                return $commits_file;
                last;
            }
        }
    }  
    if($file_found == 0){
        return -1;
    }
}


#COMMIT -a -m "message"
#Function to commit files with -a flag specified
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
                my $is_copied = 0;
                foreach my $index_file (glob ".legit/index/*"){
                    if(basename($index_file) eq basename($cwd_file) and compare($index_file,$cwd_file) != 0){
                        unlink $index_file;
                        $is_copied = 1;
                        copy($cwd_file, $index_file) or die "Couldn't copy\n";
                        next;
                    }
                }
                if($is_copied == 0){
                    my $latestCommit_file  = getLatestCommitedVersion($cwd_file);
                    if($latestCommit_file ne -1){
                        if(compare($latestCommit_file, $cwd_file) != 0){
                            copy($cwd_file, ".legit/index");
                        }
                    }
                }
            }
            #removing the -m argument
            shift @ARGV;
            legit_commit_M();
        }
    }
}

#LOG 
#Function to display commit numbers and their corresponding commit messages
sub legit_log(){
    my %num_msg; #declared but undefined
    foreach my $file (glob ".legit/commit_?/msg.txt"){
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

#SHOW 
#Function to show the 'state' of a file at any commit
sub legit_show(){
    shift @ARGV; #remove the show
    my @vals = split /:/, $ARGV[0];
    my $commit_num = $vals[0];
    my $file = $vals[1];
    if ($commit_num =~ /[0-9]+/){
    }else{
        $commit_num = -1;
    }
    
    #Checking if the repository has any commits yet
    my $file_checker = ".legit/commit_0";
    print "legit.pl: error: your repository does not have any commits yet\n" if ( !(-e $file_checker));

    #If file does not exist anyhwere
    #if (!(-e $file)){
        #print "legit.pl: error: invalid filename '$file'\n";
    if($commit_num == -1){
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
        my $f = ".legit/commit_$commit_num";
        my $found = 0;
        if(is_dir_empty("$f") == -1){
            print "legit.pl: error: unknown commit '$commit_num'\n";
        }else{
            foreach my $read_file (glob "$f/*"){
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
                    if ($file eq basename($read_file)){
                        open FILE_R, '<', $read_file or die "Cannot open read file\n";
                        foreach (<FILE_R>){
                            $found = 1;
                            print "$_";
                        }
                    }else{
                        $i++;
                    }
                    last if ($i > $commit_num);
                }  
            }
            print "legit.pl: error: '$file' not found in commit $commit_num\n" if ($found == 0);
        }
    }
}

sub legit_rm{
    shift @ARGV; #removing rm
    my $force;
    my $cached;
    if ($ARGV[0] eq "force"){
        if($ARGV[1] eq "cached"){
            #overide all checks
        }else{
            #do not print any warnings
        }
    }elsif($ARGV[0] eq "cached"){
        #remove only from index
    }
}




if ($ARGV[0] eq "init"){
    legit_init();
}elsif($ARGV[0] eq "add"){
    legit_add();
}elsif($ARGV[0] eq "commit"){
    if(!(is_initialised)){
        die "legit.pl: error: no .legit directory containing legit repository exists\n";
    }
    shift @ARGV; #removing the commit arg
    my $arg = $ARGV[0];
    #print "Arg = $arg";
    if($arg =~ /^-m$/){
        legit_commit_M();
    }else{
        legit_commit_A();
    }
}elsif($ARGV[0] eq "log"){
    if(!(is_initialised)){
        die "legit.pl: error: no .legit directory containing legit repository exists\n";
    }
    legit_log();
}elsif($ARGV[0] eq "show"){
    if(!(is_initialised)){
        die "legit.pl: error: no .legit directory containing legit repository exists\n";
    }
    legit_show();
}elsif($ARGV[0] eq "rm"){
    if(!(is_initialised)){
        die "legit.pl: error: no .legit directory containing legit repository exists\n";
    }
    legit_rm();
}
