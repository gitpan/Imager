use Config;
use ExtUtils::MakeMaker;
$Verbose = 1;

$lddl=$Config{"lddlflags"};

@plugins= qw(dyntest dt2);

$libstr=join(' ',map { $_.'.$(SO)' } @plugins);

#print $libstr,"\n";
#print $objstr,"\n";
#print MY::top_targets();

WriteMakefile(
    NAME      => 'Imager::plugins',
    SKIP      => [qw(all dynamic static )],
    clean     => {'FILES' => $libstr},
);





sub lddl_magic {
  my $t;
  $t=$lddl;
  $t=~s/-bI:\$\(PERL_INC\)\/perl.exp//;
  $t=~s/\$\(BASEEXT\)/$_[0]/;
  return $t;
}




sub MY::top_targets {
if ($^O eq 'aix') {
        '
all :: dynamic

dynamic ::       '.$libstr.(join("\n",map { qq{

$_.\$(SO): $_\$(OBJ_EXT)
	LD_RUN_PATH="\$(LD_RUN_PATH)" \$(LD) -o \$\@ }.lddl_magic($_).qq{ \$(OTHERLDFLAGS) $_\$(OBJ_EXT)

} } @plugins)).'


pure_all :: 
	\$(NOOP)

';

} else {
        '
all :: dynamic

dynamic ::       '.$libstr.(join("\n",map { qq{

$_.\$(SO): $_\$(OBJ_EXT)
	LD_RUN_PATH="\$(LD_RUN_PATH)" \$(LD) -o \$\@ \$(LDDLFLAGS) \$(OTHERLDFLAGS) $_\$(OBJ_EXT)

} } @plugins)).'


pure_all :: 
	\$(NOOP)

';

}
}
