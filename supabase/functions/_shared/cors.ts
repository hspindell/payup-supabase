export const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey',
}

export const responseSuccess = (): Response => {
  return new Response("Success", {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status: 200,
  })
}

export const responseError = (message: string): Response => {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status: 400,
  })
}