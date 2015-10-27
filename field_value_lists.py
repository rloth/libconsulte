#! /usr/bin/python3
"""
A set of ranges for dates: *-1959, 1960-79, 1980-89, 1990-99, 2000-*
 +
Hardcoded lists of values for 3 ISTEX API fields:
 - language
 - categories.wos
 - genre

why?
-----
The fields are often used as representativity criteria (the counts for
each of their values can be used as quotas for a proportional sample)

NB
---
The values-lists could be retrieved by a terms facet aggregation but the
API truncates them at count 10... Unless something changes, we'll store
a simplified copy here.        (Last copy from API + pruning 15/07/2015)
"""
__author__    = "Romain Loth"
__copyright__ = "Copyright 2014-5 INIST-CNRS (ISTEX project)"
__license__   = "LGPL"
__version__   = "0.2"
__email__     = "romain.loth@inist.fr"
__status__    = "Dev"

# ----------------------------------------------------------------------
# fields allowed as criteria
# (grouped according to the method we use for value listing)
# ----------------------------------------------------------------------
# auto value-listing via facet query
TERMFACET_FIELDS_auto = [
	'corpusName', 
	'qualityIndicators.pdfVersion', 
	'qualityIndicators.refBibsNative'
	]

# value-listing provided locally (stored into field_value_lists.py)
TERMFACET_FIELDS_local = [
	'language',
	'genre',
	'categories.wos'
	]

# binned listing via date ranges (also in field_value_lists.py)
RANGEFACET_FIELDS = [
	'publicationDate',
	'copyrightDate',
	'qualityIndicators.pdfCharCount',
	'qualityIndicators.pdfWordCount'
	]

KNOWN_FIELDS = TERMFACET_FIELDS_auto + TERMFACET_FIELDS_local + RANGEFACET_FIELDS


# ----------------------------------------------------------------------
# 4 document classification criteria => 4 schemes
#
#           3 lists of constants : LANG, GENRE, SCICAT
#           1 list of ranges (intervals) : DATE
# ----------------------------------------------------------------------


## target language list ---------------------------- 1
LANG = (
	"eng",
	"deu",
	"fre",
	# "autres"
	"((NOT eng) AND (NOT deu) AND (NOT fre))"
	)



## target genre list -------------------------------- 2
#GENRE = (
#	"article-commentary",        # ARTICLE
#	"brief-report",              # ARTICLE
#	"case-report",               # ARTICLE
#	"meeting-report",            # ARTICLE
#	"rapid-communication",       # ARTICLE
#	"research-article",          # ARTICLE
#	"review-article",            # ARTICLE
#	
#	# "abstract",          # AUTRES
#	# "book-review",       # AUTRES
#	# "letter",            # AUTRES
#	
#	# "e-book",            # EBOOK
#	)

### or simply major doctype groups
# GENRE = ("ARTICLE","EBOOK","AUTRES")


### or heuristic for {article ; others}
### (only problem: cannot take nature letters :/ )
GENRE = (
	"(article OR paper)",
	"((NOT article) AND (NOT paper))"
)
### no need for wildcards because field is tokenized and possible values as in following list (of 2015-09-23)
# 230919	bmj	research-article
# 149297	bmj	letter
# 65591	bmj	other
# 42449	bmj	book-review
# 33521	bmj	abstract
# 19716	bmj	editorial
# 207613	ecco	Primary Document
# 102688	nature	letter         <=> article-like but missing
# 87637	nature	nw
# 35151	nature	nv
# 27468	nature	book review
# 315704	oup	other
# 277998	oup	book-review
# 243736	oup	research-article
# 187142	oup	reply
# 28312	oup	letter
# 827724	springer	Original Paper
# 129795	springer	Brief Communication
# 50527	springer	Review Paper
# 2712569	wiley	Serial article




# DATE --------------------------------------------- 3
# for dates there's no categories but bins
# use case: range => bins => quotas
#~ DATE = (
	#~ ("*", 1959),
	#~ (1960, 1979),
	#~ (1980, 1989),
	#~ (1990, 1999),
	#~ (2000, "*")
	#~ )
DATE = (
	("*", 1979),
	(1980, 1999),
	(2000, "*")
	)

# SCICAT (aka academic discipline) ----------------- 4
SCAT = (
	# "WOS subject cats" scheme
	"ACOUSTICS",
	"AGRICULTURAL ECONOMICS & POLICY",
	"AGRICULTURAL ENGINEERING",
	"AGRICULTURE",
	"AGRICULTURE, DAIRY & ANIMAL SCIENCE",
	"AGRICULTURE, MULTIDISCIPLINARY",
	"AGRICULTURE, SOIL SCIENCE",
	"AGRONOMY",
	"ALLERGY",
	"ANESTHESIOLOGY",
	"ANTHROPOLOGY",
	"APPLIED LINGUISTICS",
	"AREA STUDIES",
	"ART",
	"ASTRONOMY & ASTROPHYSICS",
	"AUDIOLOGY & SPEECH-LANGUAGE PATHOLOGY",
	"AUTOMATION & CONTROL SYSTEMS",
	"BEHAVIORAL SCIENCES",
	"BIOCHEMICAL RESEARCH METHODS",
	"BIOCHEMISTRY & MOLECULAR BIOLOGY",
	"BIODIVERSITY CONSERVATION",
	"BIOLOGY",
	"BIOPHYSICS",
	"BIOTECHNOLOGY & APPLIED MICROBIOLOGY",
	"BUSINESS",
	"BUSINESS, FINANCE",
	"CARDIAC & CARDIOVASCULAR SYSTEMS",
	"CELL & TISSUE ENGINEERING",
	"CELL BIOLOGY",
	"CHEMISTRY",
	"CHEMISTRY, ANALYTICAL",
	"CHEMISTRY, APPLIED",
	"CHEMISTRY, INORGANIC & NUCLEAR",
	"CHEMISTRY, MEDICINAL",
	"CHEMISTRY, MULTIDISCIPLINARY",
	"CHEMISTRY, ORGANIC",
	"CHEMISTRY, PHYSICAL",
	"CLINICAL NEUROLOGY",
	"COMMUNICATION",
	"COMPUTER SCIENCE, ARTIFICIAL INTELLIGENCE",
	"COMPUTER SCIENCE, CYBERNETICS",
	"COMPUTER SCIENCE, HARDWARE & ARCHITECTURE",
	"COMPUTER SCIENCE, INFORMATION SYSTEMS",
	"COMPUTER SCIENCE, INTERDISCIPLINARY APPLICATIONS",
	"COMPUTER SCIENCE, SOFTWARE ENGINEERING",
	"COMPUTER SCIENCE, THEORY & METHODS",
	"CONSTRUCTION & BUILDING TECHNOLOGY",
	"CRIMINOLOGY & PENOLOGY",
	"CRITICAL CARE MEDICINE",
	"CRYSTALLOGRAPHY",
	"CULTURAL STUDIES",
	"DEMOGRAPHY",
	"DENTISTRY, ORAL SURGERY & MEDICINE",
	"DERMATOLOGY",
	"DEVELOPMENTAL BIOLOGY",
	"ECOLOGY",
	"ECONOMICS",
	"EDUCATION & EDUCATIONAL RESEARCH",
	"EDUCATION, SCIENTIFIC DISCIPLINES",
	"EDUCATION, SPECIAL",
	"ELECTROCHEMISTRY",
	"EMERGENCY MEDICINE",
	"ENDOCRINOLOGY & METABOLISM",
	"ENERGY & FUELS",
	"ENGINEERING",
	"ENGINEERING, AEROSPACE",
	"ENGINEERING, BIOMEDICAL",
	"ENGINEERING, CHEMICAL",
	"ENGINEERING, CIVIL",
	"ENGINEERING, ELECTRICAL & ELECTRONIC",
	"ENGINEERING, ENVIRONMENTAL",
	"ENGINEERING, GEOLOGICAL",
	"ENGINEERING, INDUSTRIAL",
	"ENGINEERING, MANUFACTURING",
	"ENGINEERING, MARINE",
	"ENGINEERING, MECHANICAL",
	"ENGINEERING, MULTIDISCIPLINARY",
	"ENGINEERING, OCEAN",
	"ENGINEERING, PETROLEUM",
	"ENTOMOLOGY",
	"ENVIRONMENTAL SCIENCES",
	"ENVIRONMENTAL STUDIES",
	"ERGONOMICS",
	"ETHICS",
	"ETHNIC STUDIES",
	"EVOLUTIONARY BIOLOGY",
	"FAMILY STUDIES",
	"FILM, RADIO, TELEVISION",
	"FISHERIES",
	"FOOD SCIENCE & TECHNOLOGY",
	"FORESTRY",
	"GASTROENTEROLOGY & HEPATOLOGY",
	"GENETICS & HEREDITY",
	"GEOCHEMISTRY & GEOPHYSICS",
	"GEOGRAPHY",
	"GEOGRAPHY, PHYSICAL",
	"GEOLOGY",
	"GEOSCIENCES, MULTIDISCIPLINARY",
	"GERIATRICS & GERONTOLOGY",
	"GERONTOLOGY",
	"HEALTH CARE SCIENCES & SERVICES",
	"HEALTH POLICY & SERVICES",
	"HEMATOLOGY",
	"HISTORY",
	"HISTORY & PHILOSOPHY OF SCIENCE",
	"HISTORY OF SOCIAL SCIENCES",
	"HORTICULTURE",
	"HOSPITALITY, LEISURE, SPORT & TOURISM",
	"HUMANITIES, MULTIDISCIPLINARY",
	"IMAGING SCIENCE & PHOTOGRAPHIC TECHNOLOGY",
	"IMMUNOLOGY",
	"INFECTIOUS DISEASES",
	"INFORMATION SCIENCE & LIBRARY SCIENCE",
	"INSTRUMENTS & INSTRUMENTATION",
	"INTEGRATIVE & COMPLEMENTARY MEDICINE",
	"INTERNATIONAL RELATIONS",
	"LANGUAGE & LINGUISTICS",
	"LAW",
	"LINGUISTICS",
	"LITERARY THEORY & CRITICISM",
	"LITERATURE",
	"LITERATURE, AMERICAN",
	"LITERATURE, ROMANCE",
	"LOGIC",
	"MANAGEMENT",
	"MARINE & FRESHWATER BIOLOGY",
	"MATERIALS SCIENCE",
	"MATERIALS SCIENCE, BIOMATERIALS",
	"MATERIALS SCIENCE, CERAMICS",
	"MATERIALS SCIENCE, CHARACTERIZATION & TESTING",
	"MATERIALS SCIENCE, COATINGS & FILMS",
	"MATERIALS SCIENCE, COMPOSITES",
	"MATERIALS SCIENCE, MULTIDISCIPLINARY",
	"MATERIALS SCIENCE, TEXTILES",
	"MATHEMATICAL & COMPUTATIONAL BIOLOGY",
	"MATHEMATICS",
	"MATHEMATICS, APPLIED",
	"MATHEMATICS, INTERDISCIPLINARY APPLICATIONS",
	"MECHANICS",
	"MEDICAL ETHICS",
	"MEDICAL INFORMATICS",
	"MEDICAL LABORATORY TECHNOLOGY",
	"MEDICINE, GENERAL & INTERNAL",
	"MEDICINE, LEGAL",
	"MEDICINE, RESEARCH & EXPERIMENTAL",
	"METALLURGY",
	"METALLURGY & METALLURGICAL ENGINEERING",
	"METEOROLOGY & ATMOSPHERIC SCIENCES",
	"MICROBIOLOGY",
	"MICROSCOPY",
	"MINERALOGY",
	"MINING & MINERAL PROCESSING",
	"MULTIDISCIPLINARY SCIENCES",
	"MUSIC",
	"MYCOLOGY",
	"NANOSCIENCE & NANOTECHNOLOGY",
	"NEUROIMAGING",
	"NEUROSCIENCES",
	"NUCLEAR SCIENCE & TECHNOLOGY",
	"NURSING",
	"NUTRITION & DIETETICS",
	"OBSTETRICS & GYNECOLOGY",
	"OCEANOGRAPHY",
	"ONCOLOGY",
	"OPERATIONS RESEARCH & MANAGEMENT SCIENCE",
	"OPHTHALMOLOGY",
	"OPTICS",
	"ORTHOPEDICS",
	"OTORHINOLARYNGOLOGY",
	"PALEONTOLOGY",
	"PARASITOLOGY",
	"PATHOLOGY",
	"PEDIATRICS",
	"PERIPHERAL VASCULAR DISEASE",
	"PHARMACOLOGY & PHARMACY",
	"PHILOSOPHY",
	"PHYSICS",
	"PHYSICS, APPLIED",
	"PHYSICS, ATOMIC, MOLECULAR & CHEMICAL",
	"PHYSICS, CONDENSED MATTER",
	"PHYSICS, FLUIDS & PLASMAS",
	"PHYSICS, MATHEMATICAL",
	"PHYSICS, MULTIDISCIPLINARY",
	"PHYSICS, NUCLEAR",
	"PHYSICS, PARTICLES & FIELDS",
	"PHYSIOLOGY",
	"PLANNING & DEVELOPMENT",
	"PLANT SCIENCES",
	"POLITICAL SCIENCE",
	"POLYMER SCIENCE",
	"PRIMARY HEALTH CARE",
	"PSYCHIATRY",
	"PSYCHOLOGY",
	"PSYCHOLOGY, APPLIED",
	"PSYCHOLOGY, BIOLOGICAL",
	"PSYCHOLOGY, CLINICAL",
	"PSYCHOLOGY, DEVELOPMENTAL",
	"PSYCHOLOGY, EDUCATIONAL",
	"PSYCHOLOGY, EXPERIMENTAL",
	"PSYCHOLOGY, MULTIDISCIPLINARY",
	"PSYCHOLOGY, SOCIAL",
	"PUBLIC ADMINISTRATION",
	"PUBLIC, ENVIRONMENTAL & OCCUPATIONAL HEALTH",
	"RADIOLOGY, NUCLEAR MEDICINE & MEDICAL IMAGING",
	"REHABILITATION",
	"RELIGION",
	"REMOTE SENSING",
	"REPRODUCTIVE BIOLOGY",
	"RESPIRATORY SYSTEM",
	"RHEUMATOLOGY",
	"ROBOTICS",
	"SOCIAL ISSUES",
	"SOCIAL SCIENCES, BIOMEDICAL",
	"SOCIAL SCIENCES, INTERDISCIPLINARY",
	"SOCIAL SCIENCES, MATHEMATICAL METHODS",
	"SOCIAL WORK",
	"SOCIOLOGY",
	"SOIL SCIENCE",
	"SPECTROSCOPY",
	"SPORT SCIENCES",
	"STATISTICS & PROBABILITY",
	"SUBSTANCE ABUSE",
	"SURGERY",
	"TELECOMMUNICATIONS",
	"THERMODYNAMICS",
	"TOXICOLOGY",
	"TRANSPLANTATION",
	"TRANSPORTATION",
	"TRANSPORTATION SCIENCE & TECHNOLOGY",
	"TROPICAL MEDICINE",
	"URBAN STUDIES",
	"UROLOGY & NEPHROLOGY",
	"VETERINARY SCIENCES",
	"VIROLOGY",
	"WATER RESOURCES",
	"WOMEN'S STUDIES",
	"ZOOLOGY"
)


# NBC ---------------------------------------------- 5
# bins again for number of chars <=> NBC <=> qualityIndicators.pdfCharCount
NBC = (
	("*", 1999),
	(2000, "*")
	)

# NBC ---------------------------------------------- 5
# bins again for number of chars <=> NBC <=> qualityIndicators.pdfCharCount
NBW = (
	("*", 499),
	(500, "*")
	)

