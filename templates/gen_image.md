PROMPT (Step 2: Image Generation - Per Personality)
<Task>
Generate a single period-authentic candid nightlife photograph at {{VENUE_NAME}}, {{PLACE_CITY}}, during {{TIME_WINDOW}}.
</Task>

<ConsistencyLock>
These images must form a coherent set.
- Use the exact same camera format, lens character, film response, and flash/lighting strategy for EVERY generated image in this run.
- Do NOT change time-of-day, color temperature, or lighting style between subjects.
- If in doubt, prefer the provided camera/flash/film choices verbatim rather than inventing new ones.
</ConsistencyLock>

<Subject>
Person: {{PERSON_FULL_NAME}}
Age in scene: {{PERSON_AGE}}
Wardrobe: {{WARDROBE_SPEC}}
Hair/makeup: {{HAIR_MAKEUP_SPEC}}
Expression/mood: {{EXPRESSION_SPEC}}
Pose/action: {{POSE_ACTION_SPEC}}
Companions (optional): {{COMPANIONS_SPEC}}
</Subject>

<Scene>
Location-in-venue: {{SHOT_LOCATION}} (e.g., "VIP booth", "dancefloor edge", "bar rail", "entrance line")
Shot type: {{SHOT_TYPE}} (e.g., wide / medium / close)
Composition: {{COMPOSITION_SPEC}} (framing, subject placement, foreground/background)
Background anchors: {{BACKGROUND_ANCHORS}} (from shot vocabulary; 3–6 nouns)
Crowd styling: {{CROWD_FASHION_SPEC}}
Interior design cues: {{INTERIOR_DESIGN_SPEC}}
</Scene>

<CameraAndCapture>
Still-photo authenticity target: {{STILL_LOOK_PROFILE}} (from Step 1 visual_authenticity.still_photography)
Camera format: {{CAMERA_FORMAT}}
Lens feel: {{LENS_FEEL}} (focal length impression, depth of field behavior)
Lighting strategy: {{LIGHTING_STRATEGY}} (keep identical across the set)
Exposure/flash: {{FLASH_STYLE}}
Film response: {{FILM_LOOK}} (grain, color cast, contrast)
Artifacts: {{ARTIFACTS_LIST}} (e.g., slight motion blur, halation, mild underexposure)
</CameraAndCapture>

<HardConstraints>
- Single still photo (no collage, no split panels, no multiple frames).
- Keep lighting directionality and flash behavior consistent across the set.
- Avoid generating readable new text/signage; if present, keep it indistinct.
</HardConstraints>

<References>
Use these as visual guidance (do not copy exact images):
- venue/era refs: {{REFERENCE_IMAGE_URLS}}
- wardrobe/fashion refs: {{FASHION_REFERENCE_URLS}}
</References>

<QualityBar>
- Must read as an authentic period candid photo.
- Must maintain consistent camera + lighting across all subjects.
</QualityBar>