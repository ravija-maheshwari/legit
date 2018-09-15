#!/usr/bin/perl -w
use strict;
use Cwd;
use File::Basename;
#INIT
#Initialise an empty directory .legit in the curent directory and create an empty dir .legit/index inside it
#If .legit exists, print legit.pl: error: .legit already exists
#Else print Initialized empty legit repository in .legit
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
#go through each arg which is a file name, and copy the contents of each fie from the curr dir to .legit/index/filename
#if filename does not exist in curr dir print legit.pl: error: can not open 'file_name'
#if filename is not a file print legit.pl: error: 'filename' is not a regular file
#if there are slashes and stuff print legit.pl: error: invalid filename 'filename'

sub legit_add(){
    shift @ARGV; #remove the add command
    my $curr_dir = getcwd();
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
#!/usr/bin/perl
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

#COMMIT
#if no -m message specified print usage: legit.pl commit [-a] -m commit-message
#if index is empty print nothing to commit
#if succesfully commited print Commited to commit-no
#go through all files in .legit/index and copy all of them into .legit/commit_num
#remove all commited files from index

sub legit_commit(){
    shift @ARGV; #removing the commit arg
    my $arg_m;
    my $commit_message;
    if ($arg_m = shift @ARGV) {
        if(!($arg_m =~ /^-m$/) or (!($commit_message = shift @ARGV)) ){
            print "usage: legit.pl commit [-a] -m commit-message\n";
        }else{
            my $flag = 0;
            my $commit_dir; 
            my $commit_num = 0;
            my $check_dir = is_dir_empty(".legit/index");
            
            if ($check_dir == 1){
                print "Nothing to commit\n";
            }else{
                #make a directory for commits
                while ($flag == 0){
                    $commit_dir = ".legit/commit_$commit_num";
                    #   print "Commit dir : $commit_dir\n";
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
                        print "Commited as commit $commit_num\n";
                        
                    }
                }      
            }    
        }
    }else{
        print "usage: legit.pl commit [-a] -m commit-message\n";
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

#for incorrect syntax print usage: legit.pl <commit>:<filename>
#if no filename specifed/non -existent filename specified print legit.pl: error: invalid filename '$file'
#if no commits have been made, print legit.pl: error: your repository does not have any commits yet
#NOTE:if index is empty, and no commit number is given print out the last version (last commit it was in )
#if file not found print legit.pl: error: '$file' not found in index
sub legit_show(){

}

#TBD unknown command error message to be printed for all commands if spelled wrong
if ($ARGV[0] eq "init"){
    legit_init();
}elsif($ARGV[0] eq "add"){
    legit_add();
}elsif($ARGV[0] eq "commit"){
    legit_commit();
}elsif($ARGV[0] eq "log"){
    legit_log();
}
