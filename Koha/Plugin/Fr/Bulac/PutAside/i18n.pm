package Koha::Plugin::Fr::Bulac::PutAside::i18n;

use Modern::Perl;
use utf8;
use vars qw(@ISA @EXPORT);

BEGIN {
    require Exporter;
    @ISA = qw(Exporter);

    @EXPORT = qw($i18n);
}

our $i18n = {
    en => {
        putaside => 'Put aside',
    },
    'fr-FR' => {
        putaside => 'Mettre de côté',
    }
};
