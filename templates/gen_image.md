PROMPT (Step 2: Image Generation - Per Personality)
<Task>
Generate a single period-authentic candid nightlife photograph at {{VENUE_NAME}}, {{PLACE_CITY}}, during {{TIME_WINDOW}}.
</Task>

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
Exposure/flash: {{FLASH_STYLE}}
Film response: {{FILM_LOOK}} (grain, color cast, contrast)
Artifacts: {{ARTIFACTS_LIST}} (e.g., slight motion blur, halation, mild underexposure)
</CameraAndCapture>

<References>
Use these as visual guidance (do not copy exact images):
- venue/era refs: {{REFERENCE_IMAGE_URLS}}
- wardrobe/fashion refs: {{FASHION_REFERENCE_URLS}}
</References>

<QualityBar>
- Must r
