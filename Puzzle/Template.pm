package HTML::Puzzle::Template;

$VERSION 			= "0.03";
sub Version 		{ $VERSION; }

use HTML::Template;
push @ISA,"HTML::Template";

use Carp;
use Data::Dumper;
use FileHandle;
use vars qw($DEBUG $DEBUG_FILE_PATH);
use strict;

$DEBUG 				= 0;
$DEBUG_FILE_PATH	= '/tmp/HTML-Puzzle-Template.debug.txt';

my %fields 	=
			    (
			    	autoDeleteHeader => 0
			     );
     
my @fields_req	= qw//;
my $DEBUG_FH;     

sub new
{   
	my $proto = shift;
    my $class = ref($proto) || $proto;
    # aggiungo il filtro
    my $self  = {};
    bless $self,$class;
    $self->_init_local(@_);
    push @_,('filter' => $self->_get_filter);
    # I like %TAG_NAME% syntax
    push @_,('vanguard_compatibility_mode' => 1);
    # no error if a tag present in html was not set
    push @_,('die_on_bad_params' => 0);
    $self = $class->SUPER::new(@_); 
    return $self;
}							

sub _init_local {
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

sub output {
	# redefine standard output function
	my $self = shift;
	my %args = @_;
	if (exists $args{as}) {
		my %as = %{$args{as}};
		foreach (keys %as) {
			$self->SUPER::param($_ => $as{$_});
		}
	}
	my $output = $self->SUPER::output(%args);
	return $output;
}

sub html {
	my $self 		= shift;
	my %args 		= (defined $_[0]) ? %{$_[0]} : ();
	my $filename	= $_[1];
	if (defined $filename && $filename ne $self->{options}->{filename} || $self->{_auto_parse}) {
		$self->{_auto_parse} = 0;
		$self->{options}->{filename} = $filename;
		my $filepath = $self->_find_file($filename);  
  		$self->{options}->{filepath} = $filepath;
		$self->{options}->{filter} = $self->_get_filter();
		#$self->{options}->{template} = "";
		$self->_init_template();
  		$self->_parse();
		# now that we have a full init, cache the structures if cacheing is
		# on.  shared cache is already cool.
		if($self->{options}->{file_cache}){
		$self->_commit_to_file_cache();
		}
		$self->_commit_to_cache() if (($self->{options}->{cache}
		                            and not $self->{options}->{shared_cache}
		                            and not $self->{options}->{file_cache}) or
		                            ($self->{options}->{double_cache}) or
		                            ($self->{options}->{double_file_cache}));
	}
	return $self->output('as' => \%args);
}

sub _get_filter {
	my $self = shift;
	my @ret ;
	push @ret,\&_slash_var;
	if ($self->{autoDeleteHeader}) {
		push @ret, sub {
					my $tmpl = shift;
					my $header;
					$$tmpl =~s{^.+?<body([^>'"]*|".*?"|'.*?')+>}{}msi;
					$self->{header} = $&;
					$$tmpl =~ s{</body>.+}{}msi;
				};
	}
	return \@ret;
}


sub autoDeleteHeader { 
	my $s=shift; 
	if (@_)  {
		$s->{autoDeleteHeader}=shift;
		$s->{_auto_parse} = 1;
	};
	return $s->{autoDeleteHeader}
}

sub header {my $s = shift; return exists($s->{header}) ?  $s->{header} : ''};


# funzione filtro per aggiungere il tag </TMPL_VAR> 
# da tenere fintanto che la nostra patch non sia inserita nella 
# distribuzione standard del modulo
sub _slash_var {
        my $template = shift;
        my $re_var = q{
          (<\s*                           # first <
          [Tt][Mm][Pp][Ll]_[Vv][Aa][Rr]   # interesting TMPL_VAR tag only
          (?:.*?)>)                       # this is H:T standard tag
          ((?:.*?)                        # delete alla after here
          <\s*\/                          # if there is the </TMPL_VAR> tag
          [Tt][Mm][Pp][Ll]_[Vv][Aa][Rr]
          \s*>)
        };
        # handle the </TMPL_VAR> tag
        my $re_sh = q{<\s*\/[Tt][Mm][Pp][Ll]_[Vv][Aa][Rr]\s*>};
        # String position cursor increment
        my $inc   = 15;
        while ($$template       =~ m{$re_sh}g) {
                my $prematch    = $` . $&;
                my $lpm         = length($prematch);
                my $cur         = $inc * 2 > $lpm ? $lpm : $inc * 2;
                $_              = substr($prematch,-$cur);
                my $amp; my $one;
                until ( m{$re_var}smx                           and
                                $amp = $& and $one=$1           or
                                (
                                        $cur>=$lpm+$inc         and
                                       	die "HTML::Template : </TMPL_VAR> " .
                                       		"without <TMPL_VAR>"
                                )
                        ) {
                                $_ = substr($prematch,-($cur += $inc));
                }
                $amp            = quotemeta($amp);
                $$template      =~ s{$amp}{$one}sm;
        }
}


#sub ??? {
#	# ottengo i parametri del template
#        my @tpar = $template->param();
#        # il componente Template tira fuori i parametri
#        # in lowercase, aggiusto le cose rimettendo in uppercase
#        # cio che e' necessario
#        foreach  (keys %{$self->{args}}) {
#                for (my $i=0;$i<=$#tpar;$i++) {
#                        $tpar[$i]=$_ if (lc($_) eq $tpar[$i])
#                }
#        }
#        # utilizzo quelli passati al componente
#        foreach (@tpar) {
#                if (exists(${$self->{args}}{$_})) {
#                        $template->param($_ => ${$self->{args}}{$_});
#                } else {
#                        $template->param($_ => '');
#                }
#        }
#        $_ = $template->output;
#        my $brem='<!' . '--';
#        my $eend='--' . '>';
#        my $start = qq=($brem\\s*CSTART\\s*$eend|<CSTART>)=;
#        my $end = qq=($brem\\s*CEND\\s*$eend|</CSTART>)=;
#        if (/$start(.*?)$end/msi) {
#                my $ret;
#                while(s/$start(.*?)$end//msi) {
#                        $ret .=$2;
#                }
#                return $ret
#        } else  {
#                if ($self->{autoDeleteHeader}) {
#                        s{^.+?<body([^>'"]*|".*?"|'.*?')+>}{}msi;
#                        $self->{header} = $&;
#                        s{</body>.+}{}msi;
#                }
#                return $_;
#        }
#}
#
#
sub js_header {
        # ritorna il codice javascript presente nell'header
        my $self        = shift;
        $_              = $self->{header};
        my $ret;
        my $re_init     = q|<\s*script(?:\s*\s+language\s*=\s*['"]?\s*javascript(?:.*?)['"]\s*.*?)?>|;
        my $re_end  = q|<\s*\/script\s*>|;
        while (s/$re_init.*?$re_end//msxi) {
                $ret .= $&;
        }
        return $ret;
}



1;