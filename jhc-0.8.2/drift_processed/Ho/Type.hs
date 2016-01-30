{- Generated by DrIFT (Automatic class derivations for Haskell) -}
{-# LINE 1 "src/Ho/Type.hs" #-}
module Ho.Type where

import Data.Monoid
import qualified Data.ByteString as BS
import qualified Data.Map as Map

import Data.Version
import DataConstructors(DataTable)
import E.Rules(Rules)
import E.Type
import E.TypeCheck()
import FrontEnd.Class(ClassHierarchy)
import FrontEnd.Infix(FixityMap)
import FrontEnd.KindInfer(KindEnv)
import FrontEnd.Rename(FieldMap())
import FrontEnd.SrcLoc(SrcLoc)
import FrontEnd.Tc.Type(Type())
import FrontEnd.TypeSynonyms(TypeSynonyms)
import Name.Id
import Name.Name(Name,Module)
import PackedString
import Support.CFF
import Support.MapBinaryInstance()
import qualified Support.MD5 as MD5

cff_magic = chunkType "JHC"
cff_link  = chunkType "LINK"
cff_libr  = chunkType "LIBR"
cff_jhdr  = chunkType "JHDR"
cff_core  = chunkType "CORE"
cff_defs  = chunkType "DEFS"
cff_lcor  = chunkType "LCOR"
cff_ldef  = chunkType "LDEF"
cff_idep  = chunkType "IDEP"
cff_file  = chunkType "FILE"

-- A SourceHash is the hash of a specific file, it is associated with a
-- specific 'Module' that said file implements.
type SourceHash = MD5.Hash
-- HoHash is a unique identifier for a ho file or library.
type HoHash     = MD5.Hash

-- while a 'Module' is a single Module associated with a single haskell source
-- file, a 'ModuleGroup' identifies a group of mutually recursive modules.
-- Generally it is chosen from among the Modules making up the group, but the
-- specific choice has no other meaning. We could use the HoHash, but for readability
-- reasons when debugging it makes more sense to choose an arbitrary Module.
type ModuleGroup = Module

-- the collected information that is passed around
-- this is not stored in any file, but is what is collected from the ho files.
data CollectedHo = CollectedHo {
    -- this is a list of external names that are valid but that we may not know
    -- anything else about it is used to recognize invalid ids.
    choExternalNames :: IdSet,
    -- these are the functions in Comb form.
    choCombinators  :: IdMap Comb,
    -- these are rules that may need to be retroactively applied to other
    -- modules
    choOrphanRules :: Rules,
    -- the hos
    choHoMap :: Map.Map ModuleGroup Ho,
    -- libraries depended on
    choLibDeps :: Map.Map PackedString HoHash,
    -- these are caches of pre-computed values
    choHo :: Ho, -- ^ cache of combined and renamed ho
    choVarMap :: IdMap (Maybe E) -- ^ cache of variable substitution map
    }
    {-! derive: update !-}

-- The header contains basic information about the file, it should be enough to determine whether
-- we can discard the file right away or consider it further.

data HoHeader = HoHeader {
    -- * the version of the file format. it comes first so we don't try to read data that may be in a different format.
    hohVersion  :: Int,
    -- * my sha1 id
    hohHash     :: HoHash,
    -- * the human readable name, either the ModuleGroup or the library name and version.
    hohName     :: Either ModuleGroup (PackedString,Version),
    -- * library dependencies
    hohLibDeps  :: [(PackedString,HoHash)],
    -- * arch dependencies, these say whether the file is specialized for a
    -- given arch.
    hohArchDeps :: [(PackedString,PackedString)]
    }

-- These are the dependencies needed to check if a ho file is up to date.  it
-- only appears in ho files as hl files do not have source code to check
-- against or depend on anything but other libraries.
data HoIDeps = HoIDeps {
    -- * modules depended on indexed by a hash of the source.
    hoIDeps :: Map.Map SourceHash (Module,[(Module,SrcLoc)]),
    -- * Haskell Source files depended on
    hoDepends    :: [(Module,SourceHash)],
    -- * Other objects depended on to be considered up to date.
    hoModDepends :: [HoHash],
    -- * library module groups needed
    hoModuleGroupNeeds :: [ModuleGroup]
    }

data HoLib = HoLib {
    -- * arbitrary metainformation such as library author, web site, etc.
    hoModuleMap  :: Map.Map Module ModuleGroup,
    hoReexports  :: Map.Map Module Module,
    hoModuleDeps :: Map.Map ModuleGroup [ModuleGroup],
    hoMetaInfo   :: [(PackedString,PackedString)]
    }

data Library = Library {
    libHoHeader :: HoHeader,
    libHoLib :: HoLib,
    libTcMap :: (Map.Map ModuleGroup HoTcInfo),
    libBuildMap :: (Map.Map ModuleGroup HoBuild),
    libExtraFiles :: [ExtraFile],
    libFileName :: FilePath
    }

instance Show Library where
    showsPrec n lib = showsPrec n (hohHash $ libHoHeader lib)

-- data only needed for type checking.
data HoTcInfo = HoTcInfo {
    hoExports :: Map.Map Module [Name],
    hoDefs :: Map.Map Name (SrcLoc,[Name]),
    hoAssumps :: Map.Map Name Type,        -- used for typechecking
    hoFixities :: FixityMap,
    hoKinds :: KindEnv,                    -- used for typechecking
    hoTypeSynonyms :: TypeSynonyms,
    hoClassHierarchy :: ClassHierarchy,
    hoFieldMap :: FieldMap
    }
    {-! derive: update, Monoid !-}

data HoBuild = HoBuild {
    -- Filled in by E generation
    hoDataTable :: DataTable,
    hoEs :: [(TVr,E)],
    hoRules :: Rules
    }
    {-! derive: update, Monoid !-}

data Ho = Ho {
    hoModuleGroup :: ModuleGroup,
    hoTcInfo :: HoTcInfo,
    hoBuild :: HoBuild
    }
    {-! derive: update !-}

instance Monoid Ho where
    mempty = Ho (error "unknown module group") mempty mempty
    mappend ha hb = Ho (hoModuleGroup ha) (hoTcInfo ha `mappend` hoTcInfo hb) (hoBuild ha `mappend` hoBuild hb)

data ExtraFile = ExtraFile {
    extraFileName :: PackedString,
    extraFileData :: BS.ByteString
    }

{-
instance Monoid Ho where
    mempty = Ho mempty mempty
    mappend a b = Ho {
        hoTcInfo = hoTcInfo a `mappend` hoTcInfo b,
        hoBuild = hoBuild a `mappend` hoBuild b
    }

instance Monoid HoTcInfo where
    mempty = HoTcInfo mempty mempty
    mappend a b = HoTcInfo {
        hoExports = hoExports a `mappend` hoExports b,
        hoDefs = hoDefs a `mappend` hoDefs b
    }

instance Monoid HoBuild where
    mempty = HoBuild mempty mempty mempty mempty mempty mempty mempty mempty
    mappend a b = HoBuild {
        hoAssumps = hoAssumps a `mappend` hoAssumps b,
        hoFixities = hoFixities a `mappend` hoFixities b,
        hoKinds = hoKinds a `mappend` hoKinds b,
        hoClassHierarchy = hoClassHierarchy a `mappend` hoClassHierarchy b,
        hoTypeSynonyms = hoTypeSynonyms a `mappend` hoTypeSynonyms b,
        hoDataTable = hoDataTable a `mappend` hoDataTable b,
        hoEs = hoEs a `mappend` hoEs b,
        hoRules = hoRules a `mappend` hoRules b
    }

 -}
{-* Generated by DrIFT : Look, but Don't Touch. *-}
choCombinators_u f r@CollectedHo{choCombinators  = x} = r{choCombinators = f x}
choExternalNames_u f r@CollectedHo{choExternalNames  = x} = r{choExternalNames = f x}
choHo_u f r@CollectedHo{choHo  = x} = r{choHo = f x}
choHoMap_u f r@CollectedHo{choHoMap  = x} = r{choHoMap = f x}
choLibDeps_u f r@CollectedHo{choLibDeps  = x} = r{choLibDeps = f x}
choOrphanRules_u f r@CollectedHo{choOrphanRules  = x} = r{choOrphanRules = f x}
choVarMap_u f r@CollectedHo{choVarMap  = x} = r{choVarMap = f x}
choCombinators_s v =  choCombinators_u  (const v)
choExternalNames_s v =  choExternalNames_u  (const v)
choHo_s v =  choHo_u  (const v)
choHoMap_s v =  choHoMap_u  (const v)
choLibDeps_s v =  choLibDeps_u  (const v)
choOrphanRules_s v =  choOrphanRules_u  (const v)
choVarMap_s v =  choVarMap_u  (const v)

hoAssumps_u f r@HoTcInfo{hoAssumps  = x} = r{hoAssumps = f x}
hoClassHierarchy_u f r@HoTcInfo{hoClassHierarchy  = x} = r{hoClassHierarchy = f x}
hoDefs_u f r@HoTcInfo{hoDefs  = x} = r{hoDefs = f x}
hoExports_u f r@HoTcInfo{hoExports  = x} = r{hoExports = f x}
hoFieldMap_u f r@HoTcInfo{hoFieldMap  = x} = r{hoFieldMap = f x}
hoFixities_u f r@HoTcInfo{hoFixities  = x} = r{hoFixities = f x}
hoKinds_u f r@HoTcInfo{hoKinds  = x} = r{hoKinds = f x}
hoTypeSynonyms_u f r@HoTcInfo{hoTypeSynonyms  = x} = r{hoTypeSynonyms = f x}
hoAssumps_s v =  hoAssumps_u  (const v)
hoClassHierarchy_s v =  hoClassHierarchy_u  (const v)
hoDefs_s v =  hoDefs_u  (const v)
hoExports_s v =  hoExports_u  (const v)
hoFieldMap_s v =  hoFieldMap_u  (const v)
hoFixities_s v =  hoFixities_u  (const v)
hoKinds_s v =  hoKinds_u  (const v)
hoTypeSynonyms_s v =  hoTypeSynonyms_u  (const v)

instance Monoid HoTcInfo where
    mempty = HoTcInfo mempty mempty mempty mempty mempty mempty mempty mempty
    mappend (HoTcInfo aa ab ac ad ae af ag ah) (HoTcInfo aa' ab' ac' ad' ae' af' ag' ah') = HoTcInfo (mappend aa aa')(mappend ab ab')(mappend ac ac')(mappend ad ad')(mappend ae ae')(mappend af af')(mappend ag ag')(mappend ah ah')

hoDataTable_u f r@HoBuild{hoDataTable  = x} = r{hoDataTable = f x}
hoEs_u f r@HoBuild{hoEs  = x} = r{hoEs = f x}
hoRules_u f r@HoBuild{hoRules  = x} = r{hoRules = f x}
hoDataTable_s v =  hoDataTable_u  (const v)
hoEs_s v =  hoEs_u  (const v)
hoRules_s v =  hoRules_u  (const v)

instance Monoid HoBuild where
    mempty = HoBuild mempty mempty mempty
    mappend (HoBuild aa ab ac) (HoBuild aa' ab' ac') = HoBuild (mappend aa aa')(mappend ab ab')(mappend ac ac')

hoBuild_u f r@Ho{hoBuild  = x} = r{hoBuild = f x}
hoModuleGroup_u f r@Ho{hoModuleGroup  = x} = r{hoModuleGroup = f x}
hoTcInfo_u f r@Ho{hoTcInfo  = x} = r{hoTcInfo = f x}
hoBuild_s v =  hoBuild_u  (const v)
hoModuleGroup_s v =  hoModuleGroup_u  (const v)
hoTcInfo_s v =  hoTcInfo_u  (const v)

--  Imported from other files :-
