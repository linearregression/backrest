####################################################################################################################################
# BACKUP FILE MODULE
####################################################################################################################################
package BackRest::BackupFile;

use threads;
use strict;
use Thread::Queue;
use warnings FATAL => qw(all);
use Carp qw(confess);

use File::Basename qw(dirname);
use Exporter qw(import);

use lib dirname($0);
use BackRest::Utility;
use BackRest::Exception;
use BackRest::Manifest;
use BackRest::File;

####################################################################################################################################
# backupFile
####################################################################################################################################
sub backupFile
{
    my $oFile = shift;                  # File object
    my $strSourceFile = shift;          # Source file to backup
    my $strDestinationFile = shift;     # Destination backup file
    my $bDestinationCompress = shift;   # Compress destination file
    my $strChecksum = shift;            # File checksum to be checked
    my $bChecksumOnly = shift;          # Checksum destination only
    my $lSizeFile = shift;              # Total size of the files to be copied
    my $lSizeTotal = shift;             # Total size of the files to be copied
    my $lSizeCurrent = shift;           # Size of files copied so far

    my $strLog;                     # Store the log message
    my $strLogProgress;             # Part of the log message that shows progress
    my $bCopyResult;                # Copy result
    my $strCopyChecksum;            # Copy checksum
    my $lCopySize;                  # Copy Size

    # Add the size of the current file to keep track of percent complete
    $lSizeCurrent += $lSizeFile;

    if ($bChecksumOnly)
    {
        $lCopySize = $lSizeFile;
        $strCopyChecksum = 'dude';
        # !!! Need to put checksum code in here
    }
    else
    {
        # Output information about the file to be copied
        $strLog = "backed up file";

        # Copy the file from the database to the backup (will return false if the source file is missing)
        ($bCopyResult, $strCopyChecksum, $lCopySize) =
            $oFile->copy(PATH_DB_ABSOLUTE, $strSourceFile,
                         PATH_BACKUP_TMP, $strDestinationFile .
                             ($bDestinationCompress ? '.' . $oFile->{strCompressExtension} : ''),
                         false,                   # Source is not compressed since it is the db directory
                         $bDestinationCompress,   # Destination should be compressed based on backup settings
                         true,                    # Ignore missing files
                         undef,                   # Do not set original modification time
                         undef,                   # Do not set original mode
                         true);                   # Create the destination directory if it does not exist

        if (!$bCopyResult)
        {
            # If file is missing assume the database removed it (else corruption and nothing we can do!)
            &log(INFO, "skipped file removed by database: " . $strSourceFile);

            return false, $lSizeCurrent, undef, undef;
        }
    }

    $strLogProgress = "$strSourceFile (" . file_size_format($lCopySize) .
                      ($lSizeTotal > 0 ? ', ' . int($lSizeCurrent * 100 / $lSizeTotal) . '%' : '') . ')';

    # Generate checksum for file if configured
    if ($lCopySize != 0)
    {
        # Output information about the file to be checksummed
        if (!defined($strLog))
        {
            $strLog = "checksum-only";
        }

        &log(INFO, $strLog . "  ${strLogProgress} checksum ${strCopyChecksum}");
    }
    else
    {
        &log(INFO, $strLog . ' ' . $strLogProgress);
    }

    return true, $lSizeCurrent, $lCopySize, $strCopyChecksum;
}

our @EXPORT = qw(backupFile);

####################################################################################################################################
# backupManifestUpdate
####################################################################################################################################
sub backupManifestUpdate
{
    my $oManifest = shift;
    my $strSection = shift;
    my $strFile = shift;
    my $bCopied = shift;
    my $lSize = shift;
    my $strChecksum = shift;

    # If copy was successful store the checksum and size
    if ($bCopied)
    {
        $oManifest->set($strSection, $strFile, MANIFEST_SUBKEY_SIZE, $lSize + 0);

        if ($lSize > 0)
        {
            $oManifest->set($strSection, $strFile, MANIFEST_SUBKEY_CHECKSUM, $strChecksum);
        }
    }
    # Else the file was removed during backup so remove from manifest
    else
    {
        $oManifest->remove($strSection, $strFile);
    }
}

push @EXPORT, qw(backupManifestUpdate);

1;
