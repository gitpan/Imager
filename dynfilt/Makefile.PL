
use ExtUtils::MakeMaker;
$Verbose = 1;


@plugins= qw(dyntest dt2);

$libstr=join(' ',map { $_.'.$(SO)' } @plugins);
$objstr=join(' ',map { $_.'$(OBJ_EXT)' } @plugins);

#print $libstr,"\n";
#print $objstr,"\n";
#print MY::top_targets();

WriteMakefile(
    NAME      => 'Imager::plugins',
    SKIP      => [qw(all dynamic static )],
    clean     => {'FILES' => $libstr},
);


sub MY::top_targets {
        '
all :: dynamic

dynamic ::       '.$libstr.(join("\n",map { qq{

$_.\$(SO): $_\$(OBJ_EXT)
	LD_RUN_PATH="\$(LD_RUN_PATH)" \$(LD) -o \$\@ \$(LDDLFLAGS) \$(OTHERLDFLAGS) $_\$(OBJ_EXT)
	\$(CHMOD) \$(PERM_RWX) \$\@

} } @plugins)).'


pure_all :: 
	\$(NOOP)

';


}

