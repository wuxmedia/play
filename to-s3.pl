#! /usr/bin/perl

# Script to backup db dumps to S3, and send an email on completion.

# The latest version is at http://github.com/BigRedS/play/blob/master/to-s3.pl

# There is a config file, cryptically defined as $secrets, which specifies the 
# various parameters of this. It is of the form
# key=value
# with no whitespace surrounding the equals sign. Keys to be defined are:
#   file:		local_file,  remote_key
#   S3: 		access_key_id,  secret_access_key,  bucket.
#   Reporting email:	email_to,  email_subject,  email_body,  sendmail
#
# sendmail is used in a pipe [ open($m, "|$sendmail"); ] so should be defined
# as something that can be used as such. If sendmail isn't defined, no mail 
# sending is attempted. That's as close to input validation as you get. :)
#
# In email_body, you may use any of these keywords, which are interpreted 
# sensibly. They must be in all-uppercase:
#
# FILE	 local name of the file backed up
# KEY	 key given to the file in the bucket
# BUCKET bucket used
# TODAY  today's date (YYYY-MM-DD)


my $secrets = "/home/avi/s3.secret";

use strict;
use Net::Amazon::S3; # libnet-amazon-s3-perl

# 'parse' config file to get S3 details; create S3 object
my ($accessKeyID, $secretAccessKey, $bucketName, $file, $to, $subject, $body, $sendmail, $remote_key);
open (my $f, "<", $secrets) or die "Error opening secrets file $secrets";
while (<$f>){
	unless(/^#/){
		chomp $_;
		my ($key, $value)=split(/=/, $_);

		if ($key =~ /^access_key_id$/){
			$accessKeyID = $value;
		}elsif ($key =~ /^secret_access_key$/){
			$secretAccessKey = $value;
		}elsif ($key =~ /^bucket$/){
			$bucketName=$value;
		}elsif ($key =~ /^local_file$/){
			$file=$value;
		}elsif ($key =~ /^remote_key$/){
			$remote_key=$value;
		}elsif ($key =~ /^email_to$/){
			$to=$value;
		}elsif ($key =~ /^email_subject$/){
			$subject=$value;
		}elsif ($key =~ /^email_body$/){
			$body=$value;
		}elsif ($key =~ /^sendmail$/){
			$sendmail = $value;
		}else{
			print STDERR "WARN: unrecognised option in secrets file ($secrets): $_\n";
		}
	}
}

# Since having the date might come in handy:
my @now=localtime(time());
my $year = $now[5] + 1900;
$now[4]++;
my $month = sprintf("%02d", $now[4]);
my $today="$year-$month-$now[3]";




# Here's where the S3 stuff starts

my $s3 = Net::Amazon::S3->new(
	{
		aws_access_key_id	=> $accessKeyID,
		aws_secret_access_key	=> $secretAccessKey,
		retry			=> 1
	}
);

# Uncomment this to list all the buckets, for testing etc.
#	my $response = $s3->buckets;
#	print "buckets:\n";
#	foreach my $bucket ( @{ $response->{buckets} } ) {print "\t" . $bucket->bucket . "\n";}


# spawn a bucket object from our S3 one.
my $bucket = $s3->bucket($bucketName) or die ("Error using(?) bucket $bucketName");

# variable substitution on the key:
my $key = $remote_key;
$key =~ s/FILE/$file/g;
$key =~ s/KEY/$key/g;
$key =~ s/BUCKET/$bucketName/g;
$key =~ s/TODAY/$today/g;

# Move the file across:
#$bucket->add_key_filename($key, $file) or die $s3->err .": ".$s3->errstr;

# Uncomment this to list files in the bucket, for testing etc.
#	my $response = $bucket->list_all or die $s3->err . ": " . $s3->errstr;
#	print "Bucket $bucketName contains keys:\n";
#	foreach my $key ( @{ $response->{keys} } ) {print "\t$key->{key} of size $key->{size}\n";}


## Send an email, if we want:
if ($sendmail !~ /^$/){
	$body =~ s/FILE/$file/g;
	$body =~ s/KEY/$key/g;
	$body =~ s/BUCKET/$bucketName/g;
	$body =~ s/TODAY/$today/g;
	$subject =~ s/FILE/$file/g;
	$subject =~ s/KEY/$key/g;
	$subject =~ s/BUCKET/$bucketName/g;
	$subject =~ s/TODAY/$today/g;

	open (my $m, "|$sendmail") or die "Error opening $sendmail for writing";
	print $m "To: $to\n";
	print $m "Subject: $subject\n";
	print $m "$body\n";
	close($m);
}
	
