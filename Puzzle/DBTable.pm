package HTML::Puzzle::DBTable;

require 5.005;

$VERSION 			= "0.03";
sub Version 		{ $VERSION; }

use Carp;
#use warnings;
use Data::Dumper;
use FileHandle;
use DBI;
use vars qw($DEBUG $DEBUG_FILE_PATH);
use strict;

$DEBUG 				= 0;
$DEBUG_FILE_PATH	= '/tmp/HTML-Puzzle-DBTable.debug.txt';

my %fields 	=
			    (
				    dbh			=>	undef,
					name		=> 	undef,
			     );
     
my @fields_req	= qw/dbh name/;
my $DEBUG_FH;     

sub new
{   
	my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless $self,$class;
    $self->init(@_);
    return $self;
}							

sub init {
	my $self = shift;
	my (%options) = @_;
	# Assign default options
	while (my ($key,$value) = each(%fields)) {
		$self->{$key} = $self->{$key} || $value;
    }
    # Assign options
    while (my ($key,$value) = each(%options)) {
    	$self->{$key} = $value
    }
    # Check required params
    foreach (@fields_req) {
		croak "You must declare '$_' in " . ref($self) . "::new"
				if (!defined $self->{$_});
	}
	$DEBUG_FH = new FileHandle ">>$DEBUG_FILE_PATH" if ($DEBUG);										
}

sub DESTROY {
	$DEBUG_FH->close if ($DEBUG);
}

sub add {
	my $self 	= shift;
	my $values 	= shift;
	my %values	= %{$values};
	# costruisco la stringa chiave1,chiave2,...
	my $keys	= join(',',keys(%values));
	# array dei valori
	my @values  = values(%values);
	# costruisco la stringa ?,?,?...
	my $jolly	= join(',',map('?',@values));
	my $sql 	= qq/Insert into $self->{name} ($keys) values ($jolly)/;
	debug($sql);
	$self->{dbh}->do($sql,undef,@values) or 
		die "Unable to execute $sql with params " . join(';',@values);
}

sub delete {
	my $self	= shift;
	my $id		= shift;
	my $sql		= qq/delete from $self->{name} where id = ?/;
	$self->{dbh}->do($sql,undef,$id) or 
		die "Unable to execute $sql with id $id ";
}

sub array_items {
	my $self 					= shift;
	my (undef,undef,$filter) 	= @_;
	my $sql						= $self->_item_sql(@_);
	return $self->_rec_as_array($sql,values(%{$filter}));
}

sub hash_items {
	my $self 					= shift;
	my (undef,undef,$filter) 	= @_;
	my $sql						= $self->_item_sql(@_);
	return $self->_rec_as_hash($sql,values(%{$filter}));
}


sub create {
	my $self	= shift;
	my $dbh; my $name;
	if (defined $self) {
		$dbh	= $self->{dbh};
		$name	= $self->{name};
	} else {
		my @dbInfo	= &_prompt_db_info;
		$dbh		= &_local_dbh(@dbInfo);
		$name		= $dbInfo[-1];
	}
	my $sql		=
		qq/
			CREATE TABLE $name (
	  		  id smallint(1) unsigned NOT NULL auto_increment,
			  title varchar(255) NOT NULL default '',
			  txt_short varchar(255) default NULL,
			  txt_long text,
			  link varchar(255) default NULL,
			  link_img varchar(255) default NULL,
			  enable tinyint(1) unsigned default '1',
			  data datetime NOT NULL default '0000-00-00 00:00:00',
			  ts timestamp(2) NOT NULL,
			  UNIQUE KEY id (id)
			) TYPE=MyISAM
		/;
	debug($sql);
	$dbh->do($sql) or die "Unable to execute $sql";
	if (!defined $self)	{
		print "Table $name created succesful\n";
	}
}


sub drop {
	my $self	= shift;
	my $dbh; my $name;
	if (defined $self) {
		$dbh	= $self->{dbh};
		$name	= $self->{name};
	} else {
		my @dbInfo	= &_prompt_db_info;
		$dbh		= &_local_dbh(@dbInfo);
		$name		= $dbInfo[-1];
	}
	my $sql 	= qq/drop table $name/;
	debug($sql);
	$dbh->do($sql) or die "Unable to execute $sql";	
	if (!defined $self)	{
		print "Table $name succesful dropped\n";
	}
}


sub debug {
	print {$DEBUG_FH} Data::Dumper::Dumper(shift) if ($DEBUG);
}

sub _item_sql {
	my $self 			= shift;
	my $nrow			= shift || 0;
	my $order 			= shift || "desc";
	my $filter			= shift;
	# Costruzione della stringa sql per il recupero dei dati
	my $sql  = qq/select * from $self->{name} /;
	$sql 	.= qq/where / . join (',',map("$_ = ? ",keys(%{$filter}))) 
																if ($filter);
	$sql	.= qq/order by id $order /;
	$sql	.= qq/limit $nrow/ unless ($nrow == 0);
	debug($sql);
	return $sql;
}


sub _rec_as_array {
	my $self 	= shift;
	my $sql		= shift;
	my @filter	= @_;
	my @ret;
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute(@filter) or die "Unable to execute $sql";
	push @ret,$sth->{NAME};
	while ( my @row = $sth->fetchrow_array) {
           push @ret,\@row;
    }
    debug(\@ret);
    return \@ret;
}

sub _rec_as_hash {
	my $self 	= shift;
	my $sql		= shift;
	my @filter	= @_;
	my @ret;
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute(@filter) or die "Unable to execute $sql";
	my $fldName	= $sth->{NAME};
	while ( my @row = $sth->fetchrow_array) {
	   my %row;
	   for (my $i=0;$i<scalar(@row);$i++) {
	   		$row{$fldName->[$i]} = $row[$i];
	   }
       push @ret,\%row;
    }	
    debug(\@ret);
    return \@ret;
}

sub _local_dbh {
	my ($driver,$host,$port,$db,$user,$pw) 	= @_;
	my $dsn = qq/DBI:$driver:database=$db;host=$host;port=$port/;
	my $dbh = DBI->connect($dsn, $user, $pw) 
						or die "Unable to connect to $dsn: " . $DBI::errstr;
	return $dbh;
}


sub _prompt_db_info {
	my @ret;
	my $questions=<<EOF;
Enter the DBD driver name [mysql]
Enter the database hostname [localhost]
Enter database port number [3128]
Enter database name
Enter an userid which can manage tables [root]
Enter password
Enter table name
EOF
	my @q 		= split(/\n/,$questions);
	foreach (@q) {
		my $hidden 	= 1 if (/password/i);
		my $default = '';
		if (/.+\[(.+?)\]$/) { $default = $1 }
		push @ret,&_ask_for_prompt($_,$default,$hidden);
	}
	return @ret;
}


sub _ask_for_prompt {
	my ($question,$default)  	= (shift,shift);
	my $hidden					= shift || 0;
	print $question . ': ';
	system "stty -echo" if ($hidden);
	chomp(my $word = <STDIN>);
	if ($hidden) {print "\n"; system "stty echo";}
	return $word || $default;	
}




sub dbh { my $s=shift; return @_ ? ($s->{dbh}=shift) : $s->{dbh} }
sub name { my $s=shift; return @_ ? ($s->{name}=shift) 
															: $s->{tableName} }

# Preloaded methods go here.

1;
__END__
