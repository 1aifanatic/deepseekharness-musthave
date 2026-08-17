/**
 * gemini-cli-router — DeepSeek Harness Dynamic Plugin
 * ===================================================
 * Routes DSH delegation tools to Google Gemini REST API / CLI.
 */

'use strict';

return {
  inject: ['llm', 'subprocess', 'tools'],

  apply: function (ctx) {
    if (ctx.tools && typeof ctx.tools.register === 'function') {
      ctx.tools.register({
        name: 'delegate_to_gemini',
        description: 'Send a one-shot prompt to Google Gemini 2.0 Flash or Pro without switching the main agent model.',
        parameters: {
          type: 'object',
          properties: {
            prompt: {
              type: 'string',
              description: 'The prompt to send to Gemini'
            },
            model: {
              type: 'string',
              description: 'Gemini model ID (default: gemini-2.0-flash)'
            },
            systemInstruction: {
              type: 'string',
              description: 'Optional system instruction'
            }
          },
          required: ['prompt']
        },
        execute: async function (args) {
          var apiKey = process.env.GEMINI_API_KEY;
          if (!apiKey) {
            return 'Error: GEMINI_API_KEY environment variable is not set.';
          }
          var model = args.model || 'gemini-2.0-flash';
          var endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/' + model + ':generateContent?key=' + apiKey;
          
          var payload = {
            contents: [{
              role: 'user',
              parts: [{ text: args.prompt }]
            }]
          };

          if (args.systemInstruction) {
            payload.systemInstruction = {
              parts: [{ text: args.systemInstruction }]
            };
          }

          try {
            var res = await fetch(endpoint, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(payload)
            });
            var data = await res.json();
            if (data.candidates && data.candidates[0] && data.candidates[0].content && data.candidates[0].content.parts) {
              return data.candidates[0].content.parts[0].text;
            }
            return JSON.stringify(data, null, 2);
          } catch (err) {
            return 'Gemini error: ' + String(err);
          }
        }
      });
    }
  }
};
