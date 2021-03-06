#!/usr/bin/env perl


=head1 NAME

 0048_update_biosource_v.0.02_creation.pl

=head1 SYNOPSIS

  this_script.pl [options]

  Options:

    -D <dbname> (mandatory)
      dbname to load into

    -H <dbhost> (mandatory)
      dbhost to load into

    -p <script_executor_user> (mandatory)
      username to run the script

    -F force to run this script and don't stop it by 
       missing previous db_patches

  Note: If the first time that you run this script, obviously
        you have not any previous dbversion row in the md_dbversion
        table, so you need to force the execution of this script 
        using -F

=head1 DESCRIPTION

 Update the biosource v0.01 to v0.02 with the following changes:

  + Alter table: biosource.bs_sample, add columns:
    -alternative_name
    -type_id (foreign key: public.cvterm.cvterm_id)
    -organism_id (foreign key: public.organism.organism_id)
    -stock_id
    -protocol_id (foreign key: biosource.bs_protocol.protocol_id)
    
  + Create table: biosource.bs_sample_relationship

  + Create table: biosource.bs_sample_cvterm

  + Create table: biosource.bs_sample_dbxref

 The update of the version 0.01 to 0.02 will be done in three steps 
 and three patches:

 1) update_biosource_v.0.02_creation.pl, 
    where it will create the new tables

 2) update_biosource_v.0.02_TobEA_migration.pl, 
    where it will migrate the TobEA data if it exists in the db.

 3) update_biosource_v.0.02_cleaning.pl
    where it will remove the old tables like sample_elements from
    the schema

 This will create an overlaping region between the patches 1 and 3
 where will possible the use of the two versions of the biosource 
 code.

=head1 AUTHOR

Aureliano Bombarely,
ab782@cornell.edu

=head1 COPYRIGHT & LICENSE

Copyright 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


use strict;
use warnings;

use Pod::Usage;
use Getopt::Std;
use CXGN::DB::InsertDBH;
use CXGN::Metadata::Dbversion;   ### Module to interact with the metadata.md_dbversion table


## Declaration of the parameters used to run the script

our ($opt_H, $opt_D, $opt_p, $opt_F, $opt_h);
getopts("H:D:p:Fh");

## If is used -h <help> or none parameters is detailed print pod

if (!$opt_H && !$opt_D && !$opt_p && !$opt_F && !$opt_h) {
    print STDERR "There are n\'t any tags. Print help\n\n";
    pod2usage(1);
} 
elsif ($opt_h) {
    pod2usage(1);
} 


## Declaration of the name of the script and the description

my $patch_name = '0048_update_biosource_v.0.02_creation.pl';
my $patch_descr = 'This script update the biosource schema to version 0.02 (part 1 of 3), adding some linking tables to sample.';

print STDERR "\n+--------------------------------------------------------------------------------------------------+\n";
print STDERR "Executing the patch:\n   $patch_name.\n\nDescription:\n  $patch_descr.\n\nExecuted by:\n  $opt_p.";
print STDERR "\n+--------------------------------------------------------------------------------------------------+\n\n";

## And the requeriments if you want not use all
##
my @previous_requested_patches = (   ## ADD HERE
    '0029_biosource_schema.pl',
    '0032_add_two_biosource_tables.pl'
); 

## Specify the mandatory parameters

if (!$opt_H || !$opt_D) {
    print STDERR "\nMANDATORY PARAMETER ERROR: -D <db_name> or/and -H <db_host> parameters has not been specified for $patch_name.\n";
} 

if (!$opt_p) {
    print STDERR "\nMANDATORY PARAMETER ERROR: -p <script_executor_user> parameter has not been specified for $patch_name.\n";
}

## Create the $schema object for the db_version object
## This should be replace for CXGN::DB::DBICFactory as soon as it can use CXGN::DB::InsertDBH

my $dbh =  CXGN::DB::InsertDBH->new(
                                     { 
					 dbname => $opt_D, 
					 dbhost => $opt_H 
				     }
                                   )->get_actual_dbh();

print STDERR "\nCreating the Metadata Schema object.\n";

my $metadata_schema = CXGN::Metadata::Schema->connect(   
                                                       sub { $dbh },
                                                      { on_connect_do => ['SET search_path TO metadata;'] },
                                                      );

print STDERR "\nChecking if this db_patch was executed before or if have been executed the previous db_patches.\n";

### Now it will check if you have runned this patch or the previous patches

my $dbversion = CXGN::Metadata::Dbversion->new($metadata_schema)
                                         ->complete_checking( { 
					                         patch_name  => $patch_name,
							         patch_descr => $patch_descr, 
							         prepatch_req => \@previous_requested_patches,
							         force => $opt_F 
							      } 
                                                             );


### CREATE AN METADATA OBJECT and a new metadata_id in the database for this data

my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema, $opt_p);

### Get a new metadata_id (if you are using store function you only need to supply $metadbdata object)

my $metadata_id = $metadata->store()
                           ->get_metadata_id();

### Now you can insert the data using different options:
##
##  1- By sql queryes using $dbh->do(<<EOSQL); and detailing in the tag the queries
##
##  2- Using objects with the store function
##
##  3- Using DBIx::Class first level objects
##

## In this case we will use the SQL tag

print STDERR "\nExecuting the SQL commands.\n";

$dbh->do(<<EOSQL);

-------------------------
-- biosource.bs_sample --
-------------------------

ALTER TABLE biosource.bs_sample ADD COLUMN alternative_name text;
ALTER TABLE biosource.bs_sample ADD COLUMN type_id bigint REFERENCES public.cvterm (cvterm_id);

ALTER TABLE biosource.bs_sample ADD COLUMN description_order text;
UPDATE biosource.bs_sample SET description_order=description; 
ALTER TABLE biosource.bs_sample DROP COLUMN description;
ALTER TABLE biosource.bs_sample RENAME description_order TO description;

ALTER TABLE biosource.bs_sample ADD COLUMN organism_id int REFERENCES public.organism (organism_id);
ALTER TABLE biosource.bs_sample ADD COLUMN stock_id int;
ALTER TABLE biosource.bs_sample ADD COLUMN protocol_id bigint REFERENCES biosource.bs_protocol (protocol_id);

ALTER TABLE biosource.bs_sample ADD COLUMN contact_id_order int REFERENCES sgn_people.sp_person (sp_person_id);
UPDATE biosource.bs_sample SET contact_id_order=contact_id; 
ALTER TABLE biosource.bs_sample DROP COLUMN contact_id;
ALTER TABLE biosource.bs_sample RENAME contact_id_order TO contact_id;

ALTER TABLE biosource.bs_sample ADD COLUMN metadata_id_order bigint REFERENCES metadata.md_metadata (metadata_id);
UPDATE biosource.bs_sample SET metadata_id_order=metadata_id; 
ALTER TABLE biosource.bs_sample DROP COLUMN metadata_id;
ALTER TABLE biosource.bs_sample RENAME metadata_id_order TO metadata_id;

--------------------------------------
-- biosource.bs_sample_relationship --
--------------------------------------

CREATE TABLE biosource.bs_sample_relationship (sample_relationship_id SERIAL PRIMARY KEY, subject_id int REFERENCES biosource.bs_sample (sample_id), object_id int REFERENCES biosource.bs_sample (sample_id), type_id int REFERENCES public.cvterm (cvterm_id), value text, rank int, metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_relationship_id_index ON biosource.bs_sample_relationship (sample_relationship_id);
CREATE INDEX subject_id_index ON biosource.bs_sample_relationship (subject_id);
CREATE INDEX object_id_index ON biosource.bs_sample_relationship (object_id);
CREATE INDEX type_id_index ON biosource.bs_sample_relationship (type_id);
GRANT SELECT ON biosource.bs_sample_relationship TO web_usr;
GRANT SELECT ON biosource.bs_sample_relationship_sample_relationship_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_relationship IS 'biosource.bs_sample_relationship store the associations between sample, for example an est dataset and an unigene dataset can be related with a sequence assembly relation';

------------------------------
-- biosource.bs_sample_file --
------------------------------

CREATE TABLE biosource.bs_sample_file (sample_file_id SERIAL PRIMARY KEY, sample_id int REFERENCES biosource.bs_sample (sample_id), file_id int REFERENCES metadata.md_files (file_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_file_id_index ON biosource.bs_sample_file (sample_file_id);
GRANT SELECT ON biosource.bs_sample_file TO web_usr;
GRANT SELECT ON biosource.bs_sample_file_sample_file_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_file IS 'biosource.bs_sample_file store the associations between the sample and files.';

--------------------------------
-- biosource.bs_sample_cvterm --
--------------------------------

CREATE TABLE biosource.bs_sample_cvterm (sample_cvterm_id SERIAL PRIMARY KEY, sample_id int REFERENCES biosource.bs_sample (sample_id), cvterm_id int REFERENCES public.cvterm (cvterm_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_cvterm_id_index ON biosource.bs_sample_cvterm (sample_cvterm_id);
GRANT SELECT ON biosource.bs_sample_cvterm TO web_usr;
GRANT SELECT ON biosource.bs_sample_cvterm_sample_cvterm_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_cvterm IS 'biosource.bs_sample_cvterm is a linker table to associate tags to the samples as Normalized, Sustracted...';

--------------------------------
-- biosource.bs_sample_dbxref --
--------------------------------


CREATE TABLE biosource.bs_sample_dbxref (sample_dbxref_id SERIAL PRIMARY KEY, sample_id int REFERENCES biosource.bs_sample (sample_id), dbxref_id bigint REFERENCES public.dbxref (dbxref_id), metadata_id bigint REFERENCES metadata.md_metadata (metadata_id));
CREATE INDEX sample_dbxref_id_index ON biosource.bs_sample_dbxref (sample_dbxref_id);
GRANT SELECT ON biosource.bs_sample_dbxref TO web_usr;
GRANT SELECT ON biosource.bs_sample_dbxref_sample_dbxref_id_seq TO web_usr;
COMMENT ON TABLE biosource.bs_sample_dbxref IS 'biosource.bs_sample_dbxref is a linker table to associate controlled vocabullary as Plant Ontology to each element of a sample';

EOSQL

## Now it will add this new patch information to the md_version table.  It did the dbversion object before and
## set the patch_name and the patch_description, so it only need to store it.
   

$dbversion->store($metadata);

$dbh->commit;

__END__

