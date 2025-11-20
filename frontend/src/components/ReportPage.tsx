import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';

interface Report {
  user_id: string;
  report_date: string;
  prosthesis_id: string;
  total_movements: number;
  avg_response_time_ms: number;
  max_response_time_ms: number;
  min_response_time_ms: number;
  battery_avg_percent: number;
  battery_min_percent: number;
  error_count: number;
  total_usage_hours: number;
  customer_name: string;
  customer_email: string;
  prosthesis_model: string;
  prosthesis_manufacture_date: string;
}

interface ReportResponse {
  user_id: string;
  username: string;
  date_range: {
    start: string;
    end: string;
  };
  data_available_until: string;
  total_reports: number;
  reports: Report[];
}

const ReportPage: React.FC = () => {
  const { user, logout } = useAuth();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reportData, setReportData] = useState<ReportResponse | null>(null);
  const [dataAvailableUntil, setDataAvailableUntil] = useState<string | null>(null);
  const [startDate, setStartDate] = useState<string>('');
  const [endDate, setEndDate] = useState<string>('');

  // Fetch data availability on mount
  useEffect(() => {
    const fetchDataAvailability = async () => {
      try {
        const response = await fetch('http://localhost:8000/api/reports/data-availability', {
          credentials: 'include' // Include cookies for authentication
        });
        
        if (response.ok) {
          const data = await response.json();
          if (data.data_available) {
            setDataAvailableUntil(data.latest_date);
            // Set default end date to latest available
            setEndDate(data.latest_date);
            // Set default start date to 30 days before
            const thirtyDaysAgo = new Date(data.latest_date);
            thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
            setStartDate(thirtyDaysAgo.toISOString().split('T')[0]);
          }
        }
      } catch (err) {
        console.error('Failed to fetch data availability:', err);
      }
    };

    fetchDataAvailability();
  }, []);

  const downloadReport = async () => {
    try {
      setLoading(true);
      setError(null);

      // Build query params
      const params = new URLSearchParams();
      if (startDate) params.append('start_date', startDate);
      if (endDate) params.append('end_date', endDate);

      // Call Reports API directly (includes session cookie automatically)
      const response = await fetch(`http://localhost:8000/api/reports/my-report?${params}`, {
        method: 'GET',
        credentials: 'include', // Include cookies for authentication
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.detail || `Failed to fetch report: ${response.status}`);
      }

      const data = await response.json();
      setReportData(data);
      
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

    return (
    <div className="min-h-screen bg-gray-100">
      {/* Navigation */}
      <nav className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold">BionicPRO Reports</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-gray-700">Welcome, {user?.name || user?.username}</span>
        <button
                onClick={logout}
                className="px-4 py-2 text-sm text-gray-700 hover:text-gray-900"
        >
                Logout
        </button>
      </div>
          </div>
        </div>
      </nav>

      {/* Main content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <h2 className="text-2xl font-bold mb-6">Prosthetic Usage Reports</h2>
          
          {/* User Info */}
          <div className="mb-6 p-4 bg-gray-50 rounded">
            <h3 className="font-semibold text-gray-700 mb-2">User Information</h3>
            <p className="text-sm text-gray-600">Username: {user?.username}</p>
            <p className="text-sm text-gray-600">Email: {user?.email || 'N/A'}</p>
            {dataAvailableUntil && (
              <p className="text-sm text-green-600 mt-2">
                📊 Data available until: {dataAvailableUntil}
              </p>
            )}
          </div>
          
          {/* Date Range Selection */}
          <div className="mb-6">
            <h3 className="font-semibold text-gray-700 mb-3">Select Date Range</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Start Date
                </label>
                <input
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  max={dataAvailableUntil || undefined}
                  className="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  End Date
                </label>
                <input
                  type="date"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  max={dataAvailableUntil || undefined}
                  className="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>
          </div>
        
          <button
            onClick={downloadReport}
            disabled={loading}
            className={`w-full px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-lg font-semibold ${
              loading ? 'opacity-50 cursor-not-allowed' : ''
            }`}
          >
            {loading ? '⏳ Generating Report...' : '📊 Get My Report'}
          </button>

          {error && (
            <div className="mt-4 p-4 bg-red-100 border border-red-400 text-red-700 rounded">
              <p className="text-sm font-semibold">❌ Error</p>
              <p className="text-sm">{error}</p>
            </div>
          )}
        </div>

        {/* Report Display */}
        {reportData && (
          <div className="bg-white rounded-lg shadow-md p-6">
            <div className="mb-4 flex justify-between items-center">
              <h3 className="text-xl font-bold">Report Results</h3>
              <span className="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm">
                ✓ {reportData.total_reports} reports found
              </span>
            </div>

            <div className="mb-4 text-sm text-gray-600">
              <p>Date Range: {reportData.date_range.start} to {reportData.date_range.end}</p>
              <p>User ID: {reportData.user_id}</p>
            </div>

            {reportData.reports.length === 0 ? (
              <div className="p-4 bg-yellow-50 text-yellow-800 rounded">
                <p>No reports found for the selected date range.</p>
              </div>
            ) : (
              <div className="space-y-4">
                {reportData.reports.map((report, index) => (
                  <div key={index} className="border rounded-lg p-4 hover:bg-gray-50">
                    <div className="flex justify-between items-start mb-3">
                      <div>
                        <h4 className="font-semibold text-lg">{report.prosthesis_model}</h4>
                        <p className="text-sm text-gray-600">ID: {report.prosthesis_id}</p>
                      </div>
                      <span className="px-3 py-1 bg-blue-100 text-blue-800 rounded text-sm">
                        {report.report_date}
                      </span>
                    </div>

                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div>
                        <p className="text-xs text-gray-500">Total Movements</p>
                        <p className="text-lg font-semibold">{report.total_movements.toLocaleString()}</p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Avg Response Time</p>
                        <p className="text-lg font-semibold">{report.avg_response_time_ms.toFixed(1)} ms</p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Battery Avg</p>
                        <p className="text-lg font-semibold">{report.battery_avg_percent.toFixed(1)}%</p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Usage Hours</p>
                        <p className="text-lg font-semibold">{report.total_usage_hours.toFixed(1)}h</p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Errors</p>
                        <p className={`text-lg font-semibold ${report.error_count > 0 ? 'text-red-600' : 'text-green-600'}`}>
                          {report.error_count}
                        </p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Max Response</p>
                        <p className="text-lg font-semibold">{report.max_response_time_ms.toFixed(1)} ms</p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Min Response</p>
                        <p className="text-lg font-semibold">{report.min_response_time_ms.toFixed(1)} ms</p>
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Battery Min</p>
                        <p className="text-lg font-semibold">{report.battery_min_percent.toFixed(1)}%</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default ReportPage;