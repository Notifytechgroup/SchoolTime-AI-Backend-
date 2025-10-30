import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { schoolId } = await req.json();
    
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Get user from JWT and verify authorization
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      console.error('Missing authorization header');
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: corsHeaders }
      );
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token);
    
    if (userError || !user) {
      console.error('Auth error:', userError);
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: corsHeaders }
      );
    }

    // Verify user belongs to the requested school
    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('school_id')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      console.error('Profile fetch error:', profileError);
      return new Response(
        JSON.stringify({ error: 'User profile not found' }),
        { status: 403, headers: corsHeaders }
      );
    }

    if (profile.school_id !== schoolId) {
      console.error('Authorization failed: user school_id does not match requested schoolId');
      return new Response(
        JSON.stringify({ error: 'Unauthorized: You can only generate timetables for your own school' }),
        { status: 403, headers: corsHeaders }
      );
    }

    console.log('Authorization successful for user:', user.id);

    // Fetch school data
    const { data: school } = await supabaseClient
      .from("schools")
      .select("*, timetable_template, type")
      .eq("id", schoolId)
      .single();

    // Fetch teachers with subjects
    const { data: teachers } = await supabaseClient
      .from("teachers")
      .select(`
        *,
        teacher_subjects(
          subjects(name)
        )
      `)
      .eq("school_id", schoolId);

    // Fetch streams
    const { data: streams } = await supabaseClient
      .from("streams")
      .select("*")
      .eq("school_id", schoolId);

    // Fetch constraints
    const { data: constraints } = await supabaseClient
      .from("constraints")
      .select("*")
      .eq("school_id", schoolId);

    // Fetch past timetables for reference
    const { data: uploads } = await supabaseClient
      .from("uploads")
      .select("*")
      .eq("school_id", schoolId)
      .eq("type", "past_tt");

    console.log("Fetched data:", { school, teachers, streams, constraints });

    // Build AI prompt
    const prompt = `Generate a comprehensive timetable for a ${school?.type || "primary"} school with the following details:

School Type: ${school?.type || "primary"}
Number of Streams/Classes: ${streams?.length || 0}
Streams: ${streams?.map(s => `Grade ${s.grade} ${s.stream_name}`).join(", ")}

Teachers (${teachers?.length || 0}):
${teachers?.map(t => `- ${t.name}: ${t.teacher_subjects?.map((ts: any) => ts.subjects.name).join(", ")} (${t.workload || 20} hours/week, Max: ${t.max_lessons_per_week || 25} lessons/week)`).join("\n")}

Constraints:
${constraints?.map(c => `- ${c.rule} (${c.level} level)`).join("\n") || "None specified"}

Requirements:
1. Create a weekly timetable with 5 days (Monday to Friday)
2. Each day should have 5-8 periods depending on school type
3. Assign teachers to subjects based on their specializations
4. Ensure no teacher has more than their maximum lessons per week
5. Respect all constraints provided
6. Balance subject distribution across the week
7. Avoid consecutive difficult subjects for students

Return ONLY a JSON object with this structure for each stream:
{
  "streamId": "uuid",
  "timetable": {
    "Monday": ["Math - Teacher Name", "English - Teacher Name", ...],
    "Tuesday": [...],
    "Wednesday": [...],
    "Thursday": [...],
    "Friday": [...]
  }
}

Return an array of such objects, one for each stream.`;

    // Call Lovable AI
    const LOVABLE_API_KEY = Deno.env.get("LOVABLE_API_KEY");
    if (!LOVABLE_API_KEY) {
      throw new Error("LOVABLE_API_KEY not configured");
    }

    const aiResponse = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${LOVABLE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "google/gemini-2.5-flash",
        messages: [
          {
            role: "system",
            content: "You are an expert school timetable generator. Generate realistic, balanced timetables that respect teacher constraints and pedagogical best practices. Always return valid JSON only."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
      }),
    });

    if (!aiResponse.ok) {
      const errorText = await aiResponse.text();
      console.error("AI API Error:", aiResponse.status, errorText);
      throw new Error(`AI generation failed: ${errorText}`);
    }

    const aiData = await aiResponse.json();
    const generatedContent = aiData.choices[0].message.content;
    
    console.log("AI Response:", generatedContent);

    // Parse AI response
    let timetables;
    try {
      // Extract JSON from markdown code blocks if present
      const jsonMatch = generatedContent.match(/```(?:json)?\s*(\[[\s\S]*?\])\s*```/);
      const jsonString = jsonMatch ? jsonMatch[1] : generatedContent;
      timetables = JSON.parse(jsonString);
    } catch (e) {
      console.error("Failed to parse AI response:", e);
      throw new Error("Invalid JSON response from AI");
    }

    // Save timetables to database
    const timetableInserts = timetables.map((tt: any) => ({
      school_id: schoolId,
      stream_id: tt.streamId,
      timetable_data: tt.timetable,
      generated_by: "AI",
      template_type: school?.timetable_template || "classic",
    }));

    const { data: insertedTimetables, error: insertError } = await supabaseClient
      .from("timetables")
      .insert(timetableInserts)
      .select();

    if (insertError) {
      console.error("Insert error:", insertError);
      throw insertError;
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        timetables: insertedTimetables,
        message: "Timetables generated successfully" 
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Error in generate-timetable:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to generate timetable" }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});
